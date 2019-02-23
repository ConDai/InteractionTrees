(** Properties of [Fix.mrec] and [Fix.rec]. *)

Require Import Paco.paco.

From Coq Require Import
     Program
     Lia
     Setoid
     Morphisms
     RelationClasses.

From ITree Require Import
     Basics
     Basics_Functions
     Core
     Morphisms
     MorphismsFacts
     Fix
     Effect.Sum
     Eq.Eq Eq.UpToTaus.

Section Facts.

Context {D E : Type -> Type} (ctx : D ~> itree (D +' E)).

(** Unfolding of [interp_mrec]. *)
Definition interp_mrecF R :
  itreeF (D +' E) R _ -> itree E R :=
  handleF1 (interp_mrec ctx R)
           (fun _ d k => Tau (interp_mrec ctx _ (ctx _ d >>= k))).

Lemma unfold_interp_mrecF R (t : itree (D +' E) R) :
  observe (interp_mrec ctx _ t) = observe (interp_mrecF _ (observe t)).
Proof. reflexivity. Qed.

Lemma unfold_interp_mrec R (t : itree (D +' E) R) :
  eq_itree eq
           (interp_mrec ctx _ t)
           (interp_mrecF _ (observe t)).
Proof.
  rewrite itree_eta, unfold_interp_mrecF, <-itree_eta.
  reflexivity.
Qed.

Lemma ret_mrec {T} (x: T) :
  interp_mrec ctx _ (Ret x) ≅ Ret x.
Proof. rewrite unfold_interp_mrec; reflexivity. Qed.

Lemma tau_mrec {T} (t: itree _ T) :
  interp_mrec ctx _ (Tau t) ≅ Tau (interp_mrec ctx _ t).
Proof. rewrite unfold_interp_mrec. reflexivity. Qed.

Lemma vis_mrec_right {T U} (e : E U) (k : U -> itree (D +' E) T) :
  interp_mrec ctx _ (Vis (inr1 e) k) ≅
  Vis e (fun x => interp_mrec ctx _ (k x)).
Proof. rewrite unfold_interp_mrec. reflexivity. Qed.

Lemma vis_mrec_left {T U} (d : D U) (k : U -> itree (D +' E) T) :
  interp_mrec ctx _ (Vis (inl1 d) k) ≅
  Tau (interp_mrec ctx _ (ITree.bind (ctx _ d) k)).
Proof. rewrite unfold_interp_mrec. reflexivity. Qed.

Hint Rewrite @ret_mrec : itree.
Hint Rewrite @vis_mrec_left : itree.
Hint Rewrite @vis_mrec_right : itree.
Hint Rewrite @tau_mrec : itree.

Instance eq_itree_mrec {R} :
  Proper (eq_itree eq ==> eq_itree eq) (interp_mrec ctx R).
Proof.
  repeat intro. pupto2_init. revert_until R.
  pcofix CIH. intros.
  rewrite !unfold_interp_mrec.
  pupto2_final.
  punfold H0. inv H0; pclearbot; [| |destruct e].
  - apply reflexivity.
  - pfold. econstructor. eauto.
  - pfold. econstructor. apply pointwise_relation_fold in REL.
    right. eapply CIH. rewrite REL. reflexivity.
  - pfold. econstructor. eauto 7.
Qed.

Theorem interp_mrec_bind {U T} (t : itree _ U) (k : U -> itree _ T) :
  interp_mrec ctx _ (ITree.bind t k) ≅
  ITree.bind (interp_mrec ctx _ t) (fun x => interp_mrec ctx _ (k x)).
Proof.
  intros. pupto2_init. revert t k.
  pcofix CIH. intros.
  rewrite (itree_eta t).
  destruct (observe t);
    [| |destruct e];
    autorewrite with itree;
    try rewrite <- bind_bind;
    pupto2_final.
  1: { apply reflexivity. }
  all: try (pfold; econstructor; eauto).
Qed.

Let h_mrec : D ~> itree E := mrec ctx.

Inductive mrec_invariant {U} : relation (itree _ U) :=
| mrec_main (d1 d2 : _ U) (Ed : eq_itree eq d1 d2) :
    mrec_invariant (interp_mrec ctx _ d1)
                   (interp1 (mrec ctx) _ d2)
| mrec_bind T (d : _ T) (k1 k2 : T -> itree _ U)
    (Ek : forall x, eq_itree eq (k1 x) (k2 x)) :
    mrec_invariant (interp_mrec ctx _ (d >>= k1))
                   (interp_mrec ctx _ d >>= fun x =>
                        interp1 h_mrec _ (k2 x))
.

Notation mi_holds r :=
  (forall c1 c2 d1 d2,
      mrec_invariant d1 d2 ->
      eq_itree eq c1 d1 -> eq_itree eq c2 d2 -> r c1 c2).

Lemma mrec_invariant_init {U} (r : relation (itree _ U))
      (INV : mi_holds r)
      (c1 c2 : itree _ U)
      (Ec : eq_itree eq c1 c2) :
  paco2 (compose (eq_itree_ eq) (gres2 (eq_itree_ eq))) r
        (interp_mrec ctx _ c1)
        (interp1 h_mrec _ c2).
Proof.
  rewrite unfold_interp_mrec, unfold_interp1.
  punfold Ec.
  inversion Ec; cbn; pclearbot; pupto2_final.
  + subst; apply reflexivity.
  + pfold; constructor. right; eapply INV.
    1: apply mrec_main; eassumption.
    all: reflexivity.
  + destruct e.
    { pfold; constructor; cbn; right. eapply INV.
      1: apply mrec_bind; eassumption.
      all: cbn; reflexivity.
    }
    { pfold; econstructor.
      intros; right. eapply INV.
      1: apply mrec_main; eapply REL.
      all: reflexivity.
    }
Qed.

Lemma mrec_invariant_eq {U} : mi_holds (@eq_itree _ U _ eq).
Proof.
  intros d1 d2 c1 c2 Ec1 Ec2 H.
  pupto2_init; revert d1 d2 c1 c2 Ec1 Ec2 H; pcofix self.
  intros _d1 _d2 c1 c2 [d1 d2 Ed | T d k1 k2 Ek] Ec1 Ec2.
  - rewrite Ec1, Ec2.
    apply mrec_invariant_init; auto 10.
  - rewrite Ec1, Ec2. cbn.
    rewrite unfold_interp_mrec.
    rewrite (unfold_bind (interp_mrec _ _ d)).
    unfold observe, _observe; cbn.
    destruct (observe d); fold_observe; cbn.
    + rewrite <- unfold_interp_mrec.
      apply mrec_invariant_init; auto.
    + pupto2_final; pfold; constructor; right.
      eapply self.
      1: apply mrec_bind; eassumption.
      all: cbn; fold_bind; reflexivity.
    + destruct e; cbn.
      * fold_bind. rewrite <-bind_bind.
        pupto2_final. pfold. econstructor. right.
        eapply self.
        1: apply mrec_bind; eassumption.
        all: cbn; reflexivity.
      * pupto2_final; pfold; constructor; right.
        eapply self.
        1: apply mrec_bind; eassumption.
        all: cbn; fold_bind; reflexivity.
Qed.

Theorem interp_mrec_is_interp : forall {T} (c : itree _ T),
    eq_itree eq (interp_mrec ctx _ c) (interp1 h_mrec _ c).
Proof.
  intros; eapply mrec_invariant_eq;
    try eapply mrec_main; reflexivity.
Qed.

End Facts.

Lemma rec_unfold {E A B} (f : A -> itree (callE A B +' E) B) (x : A) :
  rec f x ≈ interp (fun _ e => match e with
                               | inl1 e => calling' (rec f) _ e
                               | inr1 e => ITree.liftE e
                               end) _ (f x).
Proof.
  unfold rec. unfold mrec.
  rewrite interp_mrec_is_interp.
  repeat rewrite <- interp_is_interp1.
  unfold interp_match.
  unfold mrec.
  eapply eutt_interp.
  { red. destruct e; try reflexivity.
    destruct c.
    reflexivity. }
  reflexivity.
Qed.

Notation loop_once_ f loop_ :=
  (loop_once f (fun cb => Tau (loop_ f%function cb))).

Lemma unfold_loop'' {E A B C} (f : C + A -> itree E (C + B)) (x : C + A) :
    observe (loop_ f x)
  = observe (loop_once f (fun cb => Tau (loop_ f cb)) x).
Proof. reflexivity. Qed.

Lemma unfold_loop' {E A B C} (f : C + A -> itree E (C + B)) (x : C + A) :
    loop_ f x
  ≅ loop_once f (fun cb => Tau (loop_ f cb)) x.
Proof.
  rewrite itree_eta, (itree_eta (loop_once _ _ _)).
  reflexivity.
Qed.

Lemma unfold_loop {E A B C} (f : C + A -> itree E (C + B)) (x : C + A) :
    loop_ f x
  ≈ loop_once f (loop_ f) x.
Proof.
  rewrite unfold_loop'.
  apply eutt_bind; try reflexivity.
  intros []; try reflexivity.
  rewrite tau_eutt; reflexivity.
Qed.

Lemma unfold_aloop' {E A B} (f : A -> itree E (A + B)) (x : A) :
    aloop f x
  ≅ (ab <- f x ;;
     match ab with
     | inl a => Tau (aloop f a)
     | inr b => Ret b
     end).
Proof.
  rewrite (itree_eta (aloop _ _)), (itree_eta (ITree.bind _ _)).
  reflexivity.
Qed.

Lemma unfold_aloop {E A B} (f : A -> itree E (A + B)) (x : A) :
    aloop f x
  ≈ (ab <- f x ;;
     match ab with
     | inl a => aloop f a
     | inr b => Ret b
     end).
Proof.
  rewrite unfold_aloop'.
  apply eutt_bind; try reflexivity.
  intros []; try reflexivity.
  apply tau_eutt.
Qed.

(* Equations for a traced monoidal category *)

Lemma loop_natural_l {E A A' B C} (f : A -> itree E A')
      (body : C + A' -> itree E (C + B)) (a : A) :
    ITree.bind (f a) (loop body)
  ≅ loop (fun ca =>
      match ca with
      | inl c => Ret (inl c)
      | inr a => ITree.map inr (f a)
      end >>= body) a.
Proof.
  unfold loop.
  rewrite unfold_loop'; unfold loop_once.
  unfold ITree.map. autorewrite with itree.
  eapply eq_itree_bind; try reflexivity.
  intros a' _ []. autorewrite with itree.
  remember (inr a') as ca eqn:EQ; clear EQ a'.
  pupto2_init. revert ca; clear; pcofix self; intro ca.
  rewrite unfold_loop'; unfold loop_once.
  pupto2 @eq_itree_clo_bind; constructor; try reflexivity.
  intros [c | b].
  - match goal with
    | [ |- _ _ (Tau (loop_ ?f _)) ] => rewrite (unfold_loop' f)
    end.
    unfold loop_once_.
    rewrite ret_bind.
    pfold; constructor; auto.
  - pfold; constructor; auto.
Qed.

Lemma loop_natural_r {E A B B' C} (f : B -> itree E B')
      (body : C + A -> itree E (C + B)) (a : A) :
    loop body a >>= f
  ≅ loop (fun ca => body ca >>= fun cb =>
      match cb with
      | inl c => Ret (inl c)
      | inr b => ITree.map inr (f b)
      end) a.
Proof.
  unfold loop.
  remember (inr a) as ca eqn:EQ; clear EQ a.
  pupto2_init. revert ca; clear; pcofix self; intro ca.
  rewrite !unfold_loop'; unfold loop_once.
  rewrite !bind_bind.
  pupto2 @eq_itree_clo_bind; constructor; try reflexivity.
  intros [c | b].
  - rewrite ret_bind, tau_bind.
    pfold; constructor; auto.
  - autorewrite with itree.
    pupto2_final; apply reflexivity.
Qed.

Lemma loop_dinatural {E A B C C'} (f : C -> itree E C')
      (body : C' + A -> itree E (C + B)) (a : A) :
    loop (fun c'a => body c'a >>= fun cb =>
      match cb with
      | inl c => Tau (ITree.map inl (f c))
      | inr b => Ret (inr b)
      end) a
  ≅ loop (fun ca =>
      match ca with
      | inl c => f c >>= fun c' => Tau (Ret (inl c'))
      | inr a => Ret (inr a)
      end >>= body) a.
Proof.
  unfold loop.
  do 2 rewrite unfold_loop'; unfold loop_once.
  autorewrite with itree.
  eapply eq_itree_bind; try reflexivity.
  clear a; intros cb _ [].
  pupto2_init. revert cb; pcofix self; intros.
  destruct cb as [c | b].
  - rewrite tau_bind.
    pfold; constructor; pupto2_final; left.
    rewrite map_bind.
    rewrite (unfold_loop' _ (inl c)); unfold loop_once.
    autorewrite with itree.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    intros c'.
    rewrite tau_bind.
    rewrite ret_bind.
    rewrite unfold_loop'; unfold loop_once.
    rewrite bind_bind.
    pfold; constructor.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    auto.
  - rewrite ret_bind.
    pupto2_final; apply reflexivity.
Qed.

Lemma vanishing1 {E A B} (f : Empty_set + A -> itree E (Empty_set + B))
      (a : A) :
  loop f a ≅ ITree.map sum_empty_l (f (inr a)).
Proof.
  unfold loop.
  rewrite unfold_loop'; unfold loop_once, ITree.map.
  eapply eq_itree_bind; try reflexivity.
  intros [[]| b] _ []; reflexivity.
Qed.

Lemma vanishing2 {E A B C D} (f : D + (C + A) -> itree E (D + (C + B)))
      (a : A) :
    loop (loop f) a
  ≅ loop (fun dca => ITree.map sum_assoc_l (f (sum_assoc_r dca))) a.
Proof.
  unfold loop; rewrite 2 unfold_loop'; unfold loop_once.
  rewrite map_bind.
  rewrite unfold_loop'; unfold loop_once.
  rewrite bind_bind.
  eapply eq_itree_bind; try reflexivity.
  clear a; intros dcb _ [].
  pupto2_init. revert dcb; pcofix self; intros.
  destruct dcb as [d | [c | b]]; simpl.
  - (* d *)
    rewrite tau_bind.
    rewrite 2 unfold_loop'; unfold loop_once.
    autorewrite with itree.
    pfold; constructor.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    auto.
  - (* c *)
    rewrite ret_bind.
    rewrite 2 unfold_loop'; unfold loop_once.
    rewrite unfold_loop'; unfold loop_once.
    autorewrite with itree.
    pfold; constructor.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    auto.
  - (* b *)
    rewrite ret_bind.
    pupto2_final; apply reflexivity.
Qed.

Lemma superposing1 {E A B C D D'} (f : C + A -> itree E (C + B))
      (g : D -> itree E D') (a : A) :
    ITree.map inl (loop f a)
  ≅ loop (fun cad =>
      match cad with
      | inl c => ITree.map (sum_bimap id inl) (f (inl c))
      | inr (inl a) => ITree.map (sum_bimap id inl) (f (inr a))
      | inr (inr d) => ITree.map (inr ∘ inr) (g d)
      end) (inl a).
Proof.
  unfold loop.
  remember (inr a) as inra eqn:Hr.
  remember (inr (inl a)) as inla eqn:Hl.
  assert (Hlr : match inra with
                | inl c => inl c
                | inr a => inr (inl a)
                end = inla).
  { subst; auto. }
  clear a Hl Hr.
  unfold ITree.map.
  pupto2_init. revert inla inra Hlr; pcofix self; intros.
  rewrite 2 unfold_loop'; unfold loop_once.
  rewrite bind_bind.
  destruct inra as [c | a]; subst.
  - rewrite bind_bind; setoid_rewrite ret_bind.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    intros [c' | b]; simpl.
    + rewrite tau_bind. pfold; constructor.
      pupto2_final. auto.
    + rewrite ret_bind. pupto2_final; apply reflexivity.
  - rewrite bind_bind; setoid_rewrite ret_bind.
    pupto2 eq_itree_clo_bind; constructor; try reflexivity.
    intros [c' | b]; simpl.
    + rewrite tau_bind. pfold; constructor.
      pupto2_final. auto.
    + rewrite ret_bind. pupto2_final; apply reflexivity.
Qed.

Lemma superposing2 {E A B C D D'} (f : C + A -> itree E (C + B))
      (g : D -> itree E D') (d : D) :
    ITree.map inr (g d)
  ≅ loop (fun cad =>
      match cad with
      | inl c => ITree.map (sum_bimap id inl) (f (inl c))
      | inr (inl a) => ITree.map (sum_bimap id inl) (f (inr a))
      | inr (inr d) => ITree.map (inr ∘ inr) (g d)
      end) (inr d).
Proof.
  unfold loop; rewrite unfold_loop'; unfold loop_once.
  rewrite map_bind; unfold ITree.map.
  eapply eq_itree_bind; try reflexivity.
  intros d' _ []. reflexivity.
Qed.

Lemma yanking {E A} (a : A) :
  @loop E _ _ _ (fun aa => Ret (sum_comm aa)) a ≅ Tau (Ret a).
Proof.
  rewrite itree_eta; cbn; apply eq_itree_tau.
  rewrite itree_eta; reflexivity.
Qed.

Definition sum_map1 {A B C} (f : A -> B) (ac : A + C) : B + C :=
  match ac with
  | inl a => inl (f a)
  | inr c => inr c
  end.

Lemma bind_aloop {E A B C} (f : A -> itree E (A + B)) (g : B -> itree E (B + C)) (x : A) :
    (aloop f x >>= aloop g)
  ≈ aloop (fun ab =>
       match ab with
       | inl a => ITree.map inl (f a)
       | inr b => ITree.map (sum_map1 inr) (g b)
       end) (inl x).
Admitted.

Instance eq_itree_loop {E A B C} :
  Proper ((eq ==> eq_itree eq) ==> eq ==> eq_itree eq) (@loop E A B C).
Proof.
  repeat intro; subst.
  unfold loop.
  remember (inr _) as ca eqn:EQ; clear EQ y0.
  pupto2_init. revert ca; pcofix self; intros.
  rewrite 2 unfold_loop'; unfold loop_once.
  pupto2 eq_itree_clo_bind; constructor; try auto.
  intros [c | b]; pfold; constructor; auto.
Qed.

Section eutt_loop.

Context {E : Type -> Type} {A B C : Type}.
Variables f1 f2 : C + A -> itree E (C + B).
Hypothesis eutt_f : forall ca, f1 ca ≈ f2 ca.

Inductive loop_preinv (t1 t2 : itree E B) : Prop :=
| loop_inv_main ca :
    t1 ≅ loop_ f1 ca ->
    t2 ≅ loop_ f2 ca ->
    loop_preinv t1 t2
| loop_inv_bind u1 u2 :
    eutt eq u1 u2 ->
    t1 ≅ (cb <- u1;;
       match cb with
       | inl c => Tau (loop_ f1 (inl c))
       | inr b => Ret b
       end) ->
    t2 ≅ (cb <- u2;;
       match cb with
       | inl c => Tau (loop_ f2 (inl c))
       | inr b => Ret b
       end) ->
    loop_preinv t1 t2
.
Hint Constructors loop_preinv.

(* TODO: Make this proof less ugly. *)
Lemma eutt_loop_inv_main_step (ca : C + A) t1 t2 :
  t1 ≅ loop_ f1 ca ->
  t2 ≅ loop_ f2 ca ->
  euttF' loop_preinv
         (fun ot1 ot2 => loop_preinv (go ot1) (go ot2))
         (observe t1) (observe t2).
Proof.
  intros H1 H2.
  rewrite unfold_loop' in H1.
  rewrite unfold_loop' in H2.
  unfold loop_once.
  specialize (eutt_f ca).
  punfold eutt_f.
  destruct eutt_f.
  unfold loop_once in H1.
  rewrite unfold_bind in H1.
  destruct (observe (f1 ca)) eqn:Ef1.

  1:{ (* f1 ca = Ret _ *)
    assert (H1unalltaus : @unalltausF E _ (RetF r) (RetF r)).
    { apply untaus_all; constructor. }
    assert (H2unalltaus : finite_taus (f2 ca)).
    { apply FIN; eauto. }
    destruct H2unalltaus as [ot2 H2unalltaus].
    specialize (EQV _ _ H1unalltaus H2unalltaus).
    destruct H2unalltaus as [H2untaus _].
    unfold loop_once in H2.
    remember (f2 ca) as t2' eqn:Et2; clear Et2.
    rewrite unfold_bind in H2.
    genobs t2' ot2'.
    revert t2 H2 t2' eutt_f Heqot2'.
    induction H2untaus; intros.
    + inversion EQV; subst. rewrite <- H3 in H2; simpl in H1, H2.
      destruct r2.
      * apply eq_itree_tau_inv1 in H1.
        apply eq_itree_tau_inv1 in H2.
        destruct H1 as [t01 [Ht01 Ht01']].
        destruct H2 as [t02 [Ht02 Ht02']].
        rewrite Ht01, Ht02.
        constructor.
        econstructor.
        { rewrite Ht01'. rewrite <- itree_eta. reflexivity. }
        { rewrite Ht02'. rewrite <- itree_eta. reflexivity. }
      * apply eq_itree_ret_inv1 in H1.
        apply eq_itree_ret_inv1 in H2.
        rewrite H1, H2. auto.
    + rewrite <- OBS in H2. apply eq_itree_tau_inv1 in H2.
      destruct H2 as [t02 [Ht02 Ht02']].
      rewrite Ht02.
      constructor.
      eapply IHH2untaus; auto.
      erewrite <- (untaus_finite_taus _ (observe t')); eauto.
      rewrite <- unfold_bind; auto.
      eapply euttF_tau_right; subst; eauto. }

  2:{ (* f1 ca = Vis _ _ *)
    assert (H1unalltaus : @unalltausF E _ (VisF e k) (VisF e k)).
    { apply untaus_all; constructor. }
    assert (H2unalltaus : finite_taus (f2 ca)).
    { apply FIN; eauto. }
    destruct H2unalltaus as [ot2 H2unalltaus].
    specialize (EQV _ _ H1unalltaus H2unalltaus).
    destruct H2unalltaus as [H2untaus _].
    unfold loop_once in H2.
    remember (f2 ca) as t2' eqn:Et2; clear Et2.
    rewrite unfold_bind in H2.
    genobs t2' ot2'.
    revert t2 H2 t2' eutt_f Heqot2'.
    induction H2untaus; intros.
    + inversion EQV; auto_inj_pair2; subst.
      rewrite <- H0 in H2; simpl in H1, H2.
      apply eq_itree_vis_inv1 in H1.
      apply eq_itree_vis_inv1 in H2.
      destruct H1 as [k01 [Hk1 Ht1]].
      destruct H2 as [k02 [Hk2 Ht2]].
      rewrite Hk1, Hk2.
      pclearbot.
      constructor.
      intros; eapply loop_inv_bind; [ eapply H5 | | ]; eauto.
    + rewrite <- OBS in H2. apply eq_itree_tau_inv1 in H2.
      destruct H2 as [t02 [Ht02 Ht02']].
      rewrite Ht02.
      constructor.
      eapply IHH2untaus; auto.
      erewrite <- (untaus_finite_taus _ (observe t')); eauto.
      rewrite <- unfold_bind; auto.
      eapply euttF_tau_right; subst; eauto. }

  1:{ (* f1 ca = Tau _ *)
    unfold loop_once in H2.
    rewrite unfold_bind in H2.
    destruct (observe (f2 ca)) eqn:Ef2.

    1:{ (* f2 ca = Ret _ *)
      rewrite <- Ef1 in *; clear Ef1 t.
      assert (H2unalltaus : @unalltausF E _ (RetF r) (RetF r)).
      { apply untaus_all; constructor. }
      assert (H1unalltaus : finite_taus (f1 ca)).
      { apply FIN; eauto. }
      destruct H1unalltaus as [ot1 H1unalltaus].
      specialize (EQV _ _ H1unalltaus H2unalltaus).
      destruct H1unalltaus as [H1untaus _].
      remember (f1 ca) as t1' eqn:Et1; clear Et1.
      genobs t1' ot1'.
      revert t1 H1 t1' eutt_f Heqot1'.
      induction H1untaus; intros.
      + inversion EQV; subst. rewrite <- H0 in H1; simpl in H1, H2.
        destruct r.
        * apply eq_itree_tau_inv1 in H1.
          apply eq_itree_tau_inv1 in H2.
          destruct H1 as [t01 [Ht01 Ht01']].
          destruct H2 as [t02 [Ht02 Ht02']].
          rewrite Ht01, Ht02.
          constructor.
          econstructor.
          { rewrite Ht01'. rewrite <- itree_eta. reflexivity. }
          { rewrite Ht02'. rewrite <- itree_eta. reflexivity. }
        * apply eq_itree_ret_inv1 in H1.
          apply eq_itree_ret_inv1 in H2.
          rewrite H1, H2. auto.
      + rewrite <- OBS in H1. apply eq_itree_tau_inv1 in H1.
        destruct H1 as [t01 [Ht01 Ht01']].
        rewrite Ht01.
        constructor.
        eapply IHH1untaus; auto.
        erewrite <- (untaus_finite_taus _ (observe t')); eauto.
        rewrite <- unfold_bind; auto.
        eapply euttF_tau_left; subst; eauto. }

  2:{ (* f2 ca = Vis _ _ *)
    rewrite <- Ef1 in *; clear Ef1 t.
    assert (H2unalltaus : @unalltausF E _ (VisF e k) (VisF e k)).
    { apply untaus_all; constructor. }
    assert (H1unalltaus : finite_taus (f1 ca)).
    { apply FIN; eauto. }
    destruct H1unalltaus as [ot1 H1unalltaus].
    specialize (EQV _ _ H1unalltaus H2unalltaus).
    destruct H1unalltaus as [H1untaus _].
    remember (f1 ca) as t1' eqn:Et1; clear Et1.
    genobs t1' ot1'.
    revert t1 H1 t1' eutt_f Heqot1'.
    apply eq_notauF_vis_inv1 in EQV.
    destruct EQV as [k' [Hot0 Hk']].
    induction H1untaus; intros.
    + rewrite Hot0 in H1; simpl in H1, H2.
      apply eq_itree_vis_inv1 in H1.
      apply eq_itree_vis_inv1 in H2.
      destruct H1 as [k01 [Hk1 Ht1]].
      destruct H2 as [k02 [Hk2 Ht2]].
      rewrite Hk1, Hk2.
      pclearbot.
      constructor.
      intros; eapply loop_inv_bind; [ eapply Hk' | | ]; eauto.
    + rewrite <- OBS in H1. apply eq_itree_tau_inv1 in H1.
      destruct H1 as [t01 [Ht01 Ht01']].
      rewrite Ht01.
      constructor.
      eapply IHH1untaus; auto.
      erewrite <- (untaus_finite_taus _ (observe t')); eauto.
      rewrite <- unfold_bind; auto.
      eapply euttF_tau_left; subst; eauto. }

  1:{ (* f2 ca = Tau _ *)
    apply eq_itree_tau_inv1 in H1.
    apply eq_itree_tau_inv1 in H2.
    destruct H1 as [t01 [Ht01 Ht01']].
    destruct H2 as [t02 [Ht02 Ht02']].
    rewrite Ht01, Ht02.
    constructor.
    eapply loop_inv_bind; try (rewrite <- itree_eta; eauto).
    + erewrite <- (tauF_eutt _ t), <- (tauF_eutt _ t0); try eauto.
      pfold; auto. }
  }

Qed.

Lemma eutt_loop_inv t1 t2 :
  loop_preinv t1 t2 -> eutt eq t1 t2.
Proof.
  intros HH.
  apply eutt_is_eutt'.
  revert t1 t2 HH; pcofix self; intros. pfold.
  revert t1 t2 HH; pcofix self_tau; intros.
  destruct HH as [ca H1 H2 | u1 u2 Hu H1 H2].
  - pfold. eapply euttF'_mon.
    + eapply eutt_loop_inv_main_step; eauto.
    + intros. right. eapply self; eauto; try reflexivity.
    + simpl; intros. right.
      replace x0 with (observe (go x0)) by reflexivity.
      replace x1 with (observe (go x1)) by reflexivity.
      eapply self_tau; eauto; try reflexivity.
  - apply eutt_is_eutt' in Hu. punfold Hu. punfold Hu.
    rewrite unfold_bind in H1.
    rewrite unfold_bind in H2.
    pfold.
    genobs t1 ot1. genobs t2 ot2.
    revert ot1 ot2 t1 t2 Heqot1 Heqot2 H1 H2.
    induction Hu; intros; cbn in H1, H2; subst.
    + destruct r1 as [ c | b ].
      * apply eq_itree_tau_inv1 in H1.
        apply eq_itree_tau_inv1 in H2.
        destruct H1 as [t1'' [H1 H1']].
        destruct H2 as [t2'' [H2 H2']].
        rewrite H1, H2. constructor; eauto.
      * apply eq_itree_ret_inv1 in H1. apply eq_itree_ret_inv1 in H2.
        rewrite H1, H2. auto.
    + apply eq_itree_vis_inv1 in H1. apply eq_itree_vis_inv1 in H2.
      destruct H1 as [k1' [H1 H1']].
      destruct H2 as [k2' [H2 H2']].
      rewrite H1, H2. pclearbot. eauto.
      constructor; intro z; right.
      eapply self; eauto.
      econstructor 2.
      apply eutt_is_eutt'; apply EUTTK.
      eauto. eauto.
    + pclearbot.
      apply eq_itree_tau_inv1 in H1. apply eq_itree_tau_inv1 in H2.
      destruct H1 as [t1'' [H1 H1']].
      destruct H2 as [t2'' [H2 H2']].
      rewrite H1, H2. constructor. right.
      eapply self_tau; eauto.
      econstructor 2.
      apply eutt_is_eutt'; eauto.
      eauto. eauto.
    + apply eq_itree_tau_inv1 in H1.
      destruct H1 as [t1'' [H1 H1']].
      rewrite H1. constructor.
      eapply IHHu; eauto.
      rewrite <- unfold_bind. auto.
    + apply eq_itree_tau_inv1 in H2.
      destruct H2 as [t2'' [H2 H2']].
      rewrite H2. constructor.
      eapply IHHu; eauto.
      rewrite <- unfold_bind. auto.
Qed.

End eutt_loop.

Instance eutt_loop {E A B C} :
  Proper ((eq ==> eutt eq) ==> eq ==> eutt eq) (@loop E A B C).
Proof.
  repeat intro; subst.
  eapply eutt_loop_inv.
  - eauto.
  - unfold loop; econstructor; reflexivity.
Qed.
