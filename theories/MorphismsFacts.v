From Coq Require Import
     Program
     Setoid
     Morphisms
     RelationClasses.

From Paco Require Import paco.

From ITree Require Import
     Basics
     Core
     Effect.Sum
     Morphisms
     Eq.Eq
     Eq.UpToTaus.

(* Proof of
   [interp f (t >>= k) ~ (interp f t >>= fun r => interp f (k r))]

   "By coinduction", case analysis on t:

    - [t = Ret r] or [t = Vis e k] (...)

    - [t = Tau t]:
          interp f (Tau t >>= k)
        = interp f (Tau (t >>= k))
        = Tau (interp f (t >>= k))
        { by "coinductive hypothesis" }
        ~ Tau (interp f t >>= fun ...)
        = Tau (interp f t) >>= fun ...
        = interp f (Tau t) >>= fun ...
        (QED)

 *)

(* Unfolding of [interp]. *)
Definition interp_u {E F} (f : E ~> itree F) R :
  itreeF E R _ -> itree F R :=
  handleF (interp f _)
          (fun _ e k => Tau (ITree.bind (f _ e)
                                        (fun x => interp f _ (k x)))).

Lemma interp_unfold {E F R} {f : E ~> itree F} (t : itree E R) :
  observe (interp f _ t) = observe (interp_u f _ (observe t)).
Proof. eauto. Qed.

Lemma unfold_interp {E F R} {f : E ~> itree F} (t : itree E R) :
  interp f _ t ≅ interp_u f _ (observe t).
Proof. rewrite itree_eta, interp_unfold, <-itree_eta. reflexivity. Qed.

(* Unfolding of [interp1]. *)
Definition interp1_u {E F} (h : E ~> itree F) R :
  itreeF (E +' F) R _ -> itree F R :=
  handleF (interp1 h _)
          (fun _ ef k =>
             match ef with
             | inl1 e => Tau (ITree.bind (h _ e)
                                         (fun x => interp1 h _ (k x)))
             | inr1 f => Vis f (fun x => interp1 h _ (k x))
             end).

Lemma interp1_unfold {E F R} {f : E ~> itree F} (t : itree (E +' F) R) :
  observe (interp1 f _ t) = observe (interp1_u f _ (observe t)).
Proof. eauto. Qed.

Lemma unfold_interp1 {E F R} {f : E ~> itree F} (t : itree (E +' F) R) :
  interp1 f _ t ≅ interp1_u f _ (observe t).
Proof. rewrite itree_eta, interp1_unfold, <-itree_eta. reflexivity. Qed.

Lemma ret_interp {E F R} {f : E ~> itree F} (x: R):
  interp f _ (Ret x) ≅ Ret x.
Proof. rewrite unfold_interp. reflexivity. Qed.

Lemma tau_interp {E F R} {f : E ~> itree F} (t: itree E R):
  interp f _ (Tau t) ≅ Tau (interp f _ t).
Proof. rewrite unfold_interp. reflexivity. Qed.

Lemma vis_interp {E F R} {f : E ~> itree F} U (e: E U) (k: U -> itree E R) :
  interp f _ (Vis e k) ≅ Tau (ITree.bind (f _ e) (fun x => interp f _ (k x))).
Proof. rewrite unfold_interp. reflexivity. Qed.

Instance eq_itree_interp {E F R} f :
  Proper (@eq_itree E R ==>
          @eq_itree F R) (interp f _).
Proof.
  repeat intro. pupto2_init. revert_until R.
  pcofix CIH. intros.
  rewrite itree_eta, (itree_eta (interp f _ y)), !interp_unfold.
  punfold H0; red in H0.
  genobs x ox; destruct ox; simpobs; dependent destruction H0; simpobs; pclearbot.
  - pupto2_final. pfold. red. cbn. eauto.
  - pupto2_final. pfold. red. cbn. eauto.
  - pfold. econstructor. pupto2 (eq_itree_clo_bind F R).
    constructor.
    + reflexivity.
    + eauto. intros; pupto2_final; right; eauto.
Qed.

Instance eq_itree_interp1 {E F R} f :
  Proper (@eq_itree (E +' F) R ==>
          @eq_itree F R) (interp1 f _).
Proof.
  repeat intro. pupto2_init. revert_until R.
  pcofix CIH. intros.
  rewrite itree_eta, (itree_eta (interp1 f _ y)), !interp1_unfold.
  punfold H0; red in H0.
  genobs x ox; destruct ox; simpobs; dependent destruction H0; simpobs; pclearbot.
  - pupto2_final. pfold. red. cbn. eauto.
  - pupto2_final. pfold. red. cbn. eauto.
  - pfold. destruct e; cbn; econstructor.
    + pupto2 (eq_itree_clo_bind F R).
      constructor.
      * reflexivity.
      * intros; pupto2_final; eauto.
    + intros. pupto2_final. eauto.
Qed.

Lemma interp_bind {E F R S}
      (f : E ~> itree F) (t : itree E R) (k : R -> itree E S) :
   (interp f _ (ITree.bind t k)) ≅ (ITree.bind (interp f _ t) (fun r => interp f _ (k r))).
Proof.
  pupto2_init.
  revert R t k.
  pcofix CIH. intros.
  rewrite (itree_eta t). destruct (observe t).
  - rewrite ret_interp, !ret_bind. pupto2_final. apply eq_itree_refl.
  - rewrite tau_interp, !tau_bind, tau_interp.
    pupto2_final. pfold. econstructor. eauto.
  - rewrite vis_interp, tau_bind, bind_bind.
    pfold. do 2 red; cbn. constructor.
    pupto2 (eq_itree_clo_bind F S). econstructor.
    + reflexivity.
    + intros; specialize (CIH _ (k0 v) k); auto.
Qed.

Definition interp_match {E F} (f: E ~> itree F) : (E +' F) ~> itree F :=
  fun _ ef => match ef with inl1 e => f _ e | inr1 e => Vis e (fun r => Ret r) end.

Inductive interp_inv {E F R} (f: E ~> itree F) : relation (itree' F R) :=
| _interp_inv_main t:
    interp_inv f
      (observe (interp (interp_match f) _ t)) (observe (interp1 f _ t))
| _interp_inv_bind u t (k: u -> _):
    interp_inv f
      (observe (ITree.bind t (fun x => interp (interp_match f) _ (k x))))
      (observe (ITree.bind t (fun x => interp1 f _ (k x))))
.
Hint Constructors interp_inv.

Lemma interp_inv_main_step E F R (f: E ~> itree F) (t: itree _ R) :
  euttF' (fun x y => interp_inv f (observe x) (observe y)) (interp_inv f)
         (observe (interp (interp_match f) _ t)) (observe (interp1 f _ t)).
Proof.
  rewrite interp_unfold, interp1_unfold.
  genobs t ot. clear Heqot t.
  destruct ot; simpl; eauto.
  destruct e; simpl; eauto.
  econstructor. rewrite bind_unfold.
  econstructor. intros.
  fold_bind. rewrite bind_unfold. simpl. eauto.
Qed.

Lemma interp_is_interp1 E F R (f: E ~> itree F) (t: itree _ R) :
  interp (interp_match f) _ t ~~ interp1 f _ t.
Proof.
  revert t.
  cut (forall (t1 t2: itree _ R) (REL: interp_inv f (observe t1) (observe t2)), t1 ~~ t2).
  { eauto. }

  intros. apply eutt_is_eutt'.
  revert t1 t2 REL. pcofix CIH. intros. pfold.
  revert t1 t2 REL. pcofix CIH'. intros.
  destruct REL.
  - pfold. eapply euttF'_mon; eauto using interp_inv_main_step; intros.
    eapply upaco2_mon; eauto. intros.
    eapply (CIH' (go x2) (go x3)); eauto.
  - rewrite !bind_unfold. fold_bind.
    genobs t ot. clear Heqot t.
    destruct ot; simpl; eauto 10 using gres2.
    pfold. eapply euttF'_mon; eauto using interp_inv_main_step; intros.
    eapply upaco2_mon; eauto. intros.
    eapply (CIH' (go x2) (go x3)); eauto.
Qed.

Lemma interp_state_liftE {E F : Type -> Type} {R S : Type}
      (f : forall T, E T -> S -> itree F (S * T)%type)
      (s : S) (e : E R) :
  (interp_state f _ (ITree.liftE e) s) ≅ (f _ e s).
Proof.
Admitted.

Lemma interp_state_bind {E F : Type -> Type} {A B S : Type}
      (f : forall T, E T -> S -> itree F (S * T)%type)
      (t : itree E A) (k : A -> itree E B)
      (s : S) :
  (interp_state f _ (t >>= k) s)
    ≅
  (interp_state f _ t s >>= fun st => interp_state f _ (k (snd st)) (fst st)).
Proof.
Admitted.

Lemma interp_state_ret {E F : Type -> Type} {R S : Type}
      (f : forall T, E T -> S -> itree F (S * T)%type)
      (s : S) (r : R) :
  (interp_state f _ (Ret r) s) ≅ (Ret (s, r)).
Proof.
Admitted.
