From Coq Require Import
     Arith.PeanoNat
     Lists.List
     Strings.String
     Morphisms
     Setoid
     RelationClasses
     Logic.Classical_Prop
     Logic.EqdepFacts
     Program.Equality
.

From ExtLib Require Import
     Data.String
     Structures.Monad
     Structures.Traversable
     Data.List.

From ITree Require Import
     ITree
     ITreeFacts
     Events.MapDefault
     Events.State
     Events.StateFacts
     Core.Divergence
     Dijkstra.TracesIT
.

From Paco Require Import paco.

Import Monads.
Import MonadNotation.
Local Open Scope monad_scope.



Variant nonempty (A : Type) : Prop := ne (a : A).

Variant empty (A : Type) : Prop := emp : (A -> False) -> empty A.

Lemma classic_empty : forall A, empty A \/ nonempty A.
Proof.
  intros. destruct (classic (nonempty A)); eauto.
  left. constructor. intros. apply H. constructor; auto.
Qed.

Class Preorder :=
  {
    L : Type;
    leq : L -> L -> Prop;
  }.

(* will need more propositional constrainst on Preorders *)

Section SecureUntimed.
  Context {E : Type -> Type} {R1 R2 : Type}.
  Context (Label : Preorder).
  Context (priv : forall A, E A -> L).
  Context (RR : R1 -> R2 -> Prop).


  Inductive secure_eqitF (b1 b2 : bool) (l : L) vclo (sim : itree E R1 -> itree E R2 -> Prop) : itree' E R1 -> itree' E R2 -> Prop := 

    (* eqitF constructors *)
    | secEqRet r1 r2 : RR r1 r2 -> secure_eqitF b1 b2 l vclo sim (RetF r1) (RetF r2)
    | secEqTau t1 t2 : sim t1 t2 -> secure_eqitF b1 b2 l vclo sim (TauF t1) (TauF t2)
    | secEqTauL t1 ot2 (CHECK : b1) : secure_eqitF b1 b2 l vclo sim (observe t1) ot2 -> secure_eqitF b1 b2 l vclo sim (TauF t1) ot2
    | secEqTauR ot1 t2 (CHECK : b2) : secure_eqitF b1 b2 l vclo sim ot1 (observe t2) -> secure_eqitF b1 b2 l vclo sim ot1 (TauF t2)
    (* info_flow protecting coinductive constructors *)
    | EqVisPriv {A} (e : E A) k1 k2 (SECCHECK : leq (priv A e) l) : 
        ((forall a, vclo sim (k1 a) (k2 a) : Prop)) -> secure_eqitF b1 b2 l vclo sim (VisF e k1) (VisF e k2)
    | EqVisUnPrivTauLCo {A} (e : E A) k1 t2 (SECCHECK : ~ leq (priv A e) l) (SIZECHECK : nonempty A) :
        (forall a, vclo sim (k1 a) t2) -> secure_eqitF b1 b2 l vclo sim (VisF e k1) (TauF t2)
    | EqVisUnPrivTauRCo {A} (e : E A) t1 k2 (SECCHECK : ~ leq (priv A e) l) (SIZECHECK : nonempty A) :
        (forall a, vclo sim t1 (k2 a)) -> secure_eqitF b1 b2 l vclo sim (TauF t1) (VisF e k2)
    | EqVisUnPrivVisCo {A B} (e1 : E A) (e2 : E B) k1 k2 (SECCHECK1 : ~ leq (priv A e1) l) (SECCHECK2 : ~ leq (priv B e2) l) 
        (SIZECHECK1 : nonempty A ) (SIZECHECK2 : nonempty B) :
        (forall a b, vclo sim (k1 a) (k2 b)) -> secure_eqitF b1 b2 l vclo sim (VisF e1 k1) (VisF e2 k2)
    (* info_flow protecting inductive constructors *)
    | EqVisUnPrivLInd {A} (e : E A) k1 t2 (CHECK : b1) (SECCHECK : ~ leq (priv A e) l) (SIZECHECK : nonempty A) :
        (forall a, secure_eqitF b1 b2 l vclo sim (observe (k1 a)) (observe t2) ) ->
        secure_eqitF b1 b2 l vclo sim (VisF e k1) (observe t2)
    | EqVisUnPrivRInd {A} (e : E A) t1 k2 (CHECK : b2) (SECCHECK : ~ leq (priv A e) l) (SIZECHECK : nonempty A) :
        (forall a, secure_eqitF b1 b2 l vclo sim (observe t1) (observe (k2 a) )) ->
        secure_eqitF b1 b2 l vclo sim (observe t1) (VisF e k2)
    (* info_flow protecting constructors for halting events, should capture the notion that a secret halt means 
       that either it halted or it is performing some secret or silent computation and you can't tell which *)
    | EqVisUnprivHaltLTauR {A} (e : E A) k1 t2 (SECCHECK : ~ leq (priv A e) l ) (SIZECHECK : empty A) :
        sim (Vis e k1) t2 -> secure_eqitF b1 b2 l vclo sim (VisF e k1) (TauF t2)
    | EqVisUnprivHaltRTauL {A} (e : E A) t1 k2 (SECCHECK : ~ leq (priv A e) l ) (SIZECHECK : empty A) :
        sim t1 (Vis e k2) -> secure_eqitF b1 b2  l vclo sim (TauF t1) (VisF e k2)
    | EqVisUnprivHaltLVisR {A B} (e1 : E A) (e2 : E B) k1 k2 (SECCHECK1 : ~ leq (priv A e1) l) (SECCHECK2 : ~ leq (priv B e2) l) 
            (SIZECHECK : empty A) : 
      (forall b, vclo sim (Vis e1 k1) (k2 b) ) -> secure_eqitF b1 b2 l vclo sim (VisF e1 k1) (VisF e2 k2)
    | EqVisUnprivHaltRVisL {A B} (e1 : E A) (e2 : E B) k1 k2 (SECCHECK1 : ~ leq (priv A e1) l) (SECCHECK2 : ~ leq (priv B e2) l) 
            (SIZECHECK : empty B) :
        (forall a, vclo sim (k1 a) (Vis e2 k2)) -> secure_eqitF b1 b2 l vclo sim (VisF e1 k1) (VisF e2 k2) 
  .

  Hint Constructors secure_eqitF : core.

  Definition secure_eqit_ (b1 b2 : bool) (l : L) vclo (sim : itree E R1 -> itree E R2 -> Prop) : itree E R1 -> itree E R2 -> Prop :=
    fun t1 t2 => secure_eqitF b1 b2 l vclo sim (observe t1) (observe t2).

  Hint Unfold secure_eqit_ : core.

  Lemma secure_eqitF_mono b1 b2 l x0 x1 vclo vclo' sim sim'
        (IN: secure_eqitF b1 b2 l vclo sim x0 x1)
        (MON: monotone2 vclo)
        (LEc: vclo <3= vclo')
        (LE: sim <2= sim'):
    secure_eqitF b1 b2 l vclo' sim' x0 x1.
  Proof.
    intros. induction IN; eauto.
  Qed.

  Lemma secure_eqit_mono b1 b2 l vclo (MON: monotone2 vclo) : monotone2 (secure_eqit_ b1 b2 l vclo).
  Proof.
    do 2 red. intros; eapply secure_eqitF_mono; eauto.
  Qed.

  Hint Resolve secure_eqit_mono : paco.

  Definition eqit_secure b1 b2 l := paco2 (secure_eqit_ b1 b2 l id) bot2.

  (* want and eqitC_secure which could help prove some interesting stuff

   *)


  (*
    Note that this is not reflexive (think it is symmetric and transitive) 
    Suppose SecureFlip : E bool has privilege 1 and trigger SecureFlip is 
    observed at privilege 0. We end to prove eqit_secure false false 0 of it 
    requires us to show forall a b, eqit_secure false false 0 (Ret a) (Ret b)
    this is false, suppose a = true and b = false and the relation is equality

   *)


End SecureUntimed.

Hint Resolve secure_eqit_mono : paco.

Hint Constructors secure_eqitF : core.

Definition NatPreorder : Preorder :=
  {|
  L := nat;
  leq := fun n m => n <= m
  |}.

Section SecureUntimedUnReflexive.
  
  Variant NonDet : Type -> Type :=
    | SecureFlip : NonDet bool
    | PublicOut : NonDet unit
    | Halt : NonDet void

. 

(* 
CoInductive itree E R :=
...
| Vis {A : Type} (e : E A) (k : A -> itree E R)

suppose A := void

k ≅ empty_cont

bind (Vis Halt k1) k2 ≅ Vis Halt k1 

E := HaltE unit

Definition halt : itree E R := Vis HaltE (fun _ => Tau Tau ...)

*)

  Definition priv_counter : forall A, NonDet A -> nat :=
    fun _ e =>
      match e with
      | SecureFlip => 1
      | PublicOut => 0 
      | Halt => 10
      end.
  

  Variant Exc : Type -> Type :=
    Throw : Exc void.

  Definition refl_counter : itree NonDet bool := trigger SecureFlip. (* b := Flip; return b *)

  Lemma refl_counter_counter : ~ eqit_secure NatPreorder priv_counter eq true true 0 refl_counter refl_counter.
    Proof.
      intro Hcontra. punfold Hcontra; try eapply secure_eqit_mono; eauto.
      red in Hcontra. cbn in *. inv Hcontra; ITrace.inj_existT; subst.
      - cbv in SECCHECK. inv SECCHECK.
      - specialize (H0 true false). pclearbot. pinversion H0; try eapply secure_eqit_mono; eauto.
        discriminate.
      - rewrite H3 in H0. clear H3. specialize (H0 true). cbn in *.
        inv H0; ITrace.inj_existT; subst. specialize (H2 false). rewrite H in H2.
        inv H2. discriminate.
      -  rewrite H in H0. injection H0; intros; ITrace.inj_existT; subst; ITrace.inj_existT; subst.
         specialize (H1 true). cbn in *. inv H1; ITrace.inj_existT; subst; ITrace.inj_existT; subst.
         rewrite H6 in H3. specialize (H3 false). cbn in *. inv H3; discriminate.
      - inv SIZECHECK. apply H; apply true.
      - inv SIZECHECK. apply H; apply true.
    Qed.


    Lemma halt_not_ret : forall A (a : A) k, ~ eqit_secure NatPreorder priv_counter eq true true 0 (Vis Halt k) (Ret a).
    Proof.
      intros. intro Hcontra. pinversion Hcontra. ITrace.inj_existT; subst.
      inv SIZECHECK. contradiction.
    Qed.

    Lemma halt_spin : eqit_secure NatPreorder priv_counter eq true true 0 (trigger Halt) (ITree.spin).
    Proof.
      pcofix CIH. pfold. red. cbn. eapply EqVisUnprivHaltLTauR.
      - intro. inv H.
      - constructor. intros; contradiction.
      - right. apply CIH.
    Qed.



    (*transitivity problems in presence of E void *)
    Definition refl_counter2 : itree NonDet unit := ITree.bind refl_counter (fun b : bool => if b then Ret tt else trigger PublicOut).
    (* b := SecretFlip; if b then return tt else PublicOut; return tt*)
    Lemma refl_counter2_counter : ~ eqit_secure NatPreorder priv_counter eq true true 0 refl_counter2 refl_counter2.
      Proof.
        unfold refl_counter2. intro Hcontra. punfold Hcontra; try eapply secure_eqit_mono; eauto.
        red in Hcontra. cbn in Hcontra. inv Hcontra; ITrace.inj_existT; subst; try (inv SIZECHECK; apply H; constructor; fail).
        - inv SECCHECK.
        - specialize (H0 true false). pclearbot. punfold H0; try eapply secure_eqit_mono; eauto.
          red in H0. cbn in *. inv H0; ITrace.inj_existT; subst.
          cbn in *. apply SECCHECK; auto.
        - rewrite H3 in H0; clear H3. specialize (H0 true). cbn in *.
          inv H0; ITrace.inj_existT; subst; ITrace.inj_existT.
          specialize (H2 false). rewrite H in H2. cbn in *. inv H2; 
          ITrace.inj_existT; subst; apply SECCHECK1; constructor.
        - rewrite <- H0 in H. injection H; intros; ITrace.inj_existT; subst; ITrace.inj_existT; subst.
          specialize (H1 true). inv H1; ITrace.inj_existT; subst.
          rewrite H6 in H3. specialize (H3 false). cbn in *.
          inv H3; ITrace.inj_existT; subst. apply SECCHECK1; constructor.
      Qed.
          

Section eqit_secureC.
  (* might not be the order I eventually want but whatever*)
  Context {E: Type -> Type} {R1 R2 : Type} (RR : R1 -> R2 -> Prop).
  Context (Label : Preorder) (priv : forall A, E A -> L) (l : L).


  Variant eqit_secure_trans_clo (b1 b2 b1' b2' : bool) (r : itree E R1 -> itree E R2 -> Prop) : 
    itree E R1 -> itree E R2 -> Prop :=
        eqit_secure_trans_clo_intro t1 t2 t1' t2' RR1 RR2
      (EQVl: eqit_secure Label priv RR1 b1 b1' l t1 t1')
      (EQVr: eqit_secure Label priv RR2 b2 b2' l t2 t2')
      (REL: r t1' t2')
      (LERR1: forall x x' y, RR1 x x' -> RR x' y -> RR x y)
      (LERR2: forall x y y', RR2 y y' -> RR x y' -> RR x y) :
      eqit_secure_trans_clo b1 b2 b1' b2' r t1 t2.

  Hint Constructors eqit_secure_trans_clo : core.

  Definition eqit_secureC b1 b2 := eqit_secure_trans_clo b1 b2 false false.
  Hint Unfold eqit_secureC : core.

  Lemma eqit_secureC_mon b1 b2 r1 r2 t1 t2 
    (IN : eqit_secureC b1 b2 r1 t1 t2)
    (LE: r1 <2= r2) : 
    eqit_secureC b1 b2 r2 t1 t2.
  Proof.
    destruct IN; eauto.
  Qed.


  

End eqit_secureC.
 
  

Ltac unpriv_co := try apply EqVisUnPrivVisCo; 
                  try apply EqVisUnPrivTauLCo; 
                  try apply EqVisUnPrivTauRCo; 
                  auto; intros.

Ltac unpriv_ind := try apply EqVisUnPrivLInd;
                   try apply EqVisUnPrivRInd;
                   auto; intros.

Ltac unpriv_halt :=
  match goal with
  | [  Hemp : empty ?A |- secure_eqitF _ _ _ _ _ _ _ _ (@VisF _ _ _ ?A _ _) _ ] =>
    try apply  EqVisUnprivHaltLTauR; try apply EqVisUnprivHaltLVisR; auto; intros

  | [  Hemp : empty ?A |- secure_eqitF _ _ _ _ _ _ _ _ _ (@VisF _ _ _ ?A _ _)  ] =>
    try apply EqVisUnprivHaltRTauL; try apply EqVisUnprivHaltRVisL; auto; intros end.

Ltac contra_size :=
  match goal with
  | [ Hemp : empty ?A, Hne : nonempty ?A |- _ ] => inv Hemp; inv Hne; contradiction end.

(*
Ltac unpriv_halt := try apply EqVisUnprivHaltLTauR;
                    try apply EqVisUnprivHaltRTauL;
                    try apply 
*)
Ltac gfinal_with H := gfinal; left; apply H.

Ltac ne A := let Hne := fresh "H" in assert (Hne : nonempty A); eauto; inv Hne.   
    
Lemma eqit_secure_sym : forall b1 b2 E R1 R2 RR Label priv l (t1 : itree E R1) (t2 : itree E R2),
    eqit_secure Label priv RR b1 b2 l t1 t2 -> eqit_secure Label priv (flip RR) b2 b1 l t2 t1.
Proof.
  intros b1 b2 E R1 R2 RR Label priv l. pcofix CIH.
  intros t1 t2 Hsec. pfold. red. punfold Hsec. red in Hsec.
  hinduction Hsec before r; intros; eauto; pclearbot;
  try (unpriv_co; right; apply CIH; apply H);
  try unpriv_halt.
  - constructor; auto. intros. right. apply CIH; apply H.
  - specialize (H a). remember (k2 a) as t. clear Heqt k2.
     left.
     intros. pfold. red. cbn. punfold H. red in H. cbn in H.
     inv H; ITrace.inj_existT; subst; try contra_size; try contradiction; pclearbot; eauto;
     try (unpriv_halt; fail).
     +  unpriv_halt. right. apply CIH. pfold. auto.
     + rewrite H0. rewrite H0 in H2. unpriv_halt.
       right. apply CIH. pfold. apply H2.
     + unpriv_halt. right. apply CIH. apply H1.
     + unpriv_halt. right. apply CIH. apply H1.
  - specialize (H b). remember (k1 b) as t. clear Heqt k1.
     left.
     intros. pfold. red. cbn. punfold H. red in H. cbn in H.
     inv H; ITrace.inj_existT; subst; try contra_size; try contradiction; pclearbot; eauto;
     try (unpriv_halt; fail).
     +  unpriv_halt. right. apply CIH. pfold. auto.
     + rewrite H1. rewrite H1 in H2. unpriv_halt.
       right. apply CIH. pfold. apply H2.
     + unpriv_halt. inv SIZECHECK0. contradiction.
     + unpriv_halt. right. apply CIH. apply H2.
Qed.

Lemma secure_eqit_mon : forall E (b1 b2 b3 b4 : bool) R1 R2 RR1 RR2 Label priv l 
      (t1 : itree E R1) (t2 : itree E R2),
    (b1 -> b3) -> (b2 -> b4) -> (RR1 <2= RR2) ->
    eqit_secure Label priv RR1 b1 b2 l t1 t2 -> eqit_secure Label priv RR2 b3 b4 l t1 t2.
Proof.
  intros. generalize dependent t2. revert t1. pcofix CIH.
  intros t1 t2 Ht12. pstep. red.
  punfold Ht12. red in Ht12.
  hinduction Ht12 before r; intros; eauto; pclearbot;
  try (unpriv_co; right; apply CIH; try red; eauto; fail);
  try (unpriv_halt; try contra_size; right; apply CIH; try red; eauto; fail).
  constructor; auto. right.  eauto. apply CIH; apply H2.
Qed.

Section Transitivity.


  Context (E : Type -> Type) (R : Type) (Label : Preorder) (priv : forall A, E A -> L).
  Context (l : L).
  Context (Hhalt_vis : forall A (e : E A), nonempty A -> leq (priv A e) l).

End Transitivity.

End SecureUntimedUnReflexive.

Section SecureTimed.

  Variant TimedEv (E : Type -> Type) : Type -> Type :=
    | TE {A : Type} (e : E A) (n : nat) : TimedEv E A.

  Fixpoint handle_timed_aux {E A} (e : E A) (n : nat) : itree E A :=
    match n with
    | 0 => Vis e (fun a => Ret a)
    | S m => Tau (handle_timed_aux e m) end.

  Definition handle_timed {E A} (e : TimedEv E A) : itree E A :=
    match e with TE _ e' a => handle_timed_aux e' a end.


End SecureTimed.
