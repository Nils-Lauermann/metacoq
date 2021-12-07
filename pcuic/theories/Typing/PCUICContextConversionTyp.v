(* Distributed under the terms of the MIT license. *)
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICOnOne PCUICAstUtils
     PCUICLiftSubst PCUICTyping PCUICWeakeningConv PCUICWeakeningTyp PCUICCases
     PCUICCumulativity PCUICReduction
     PCUICParallelReduction PCUICEquality PCUICUnivSubstitutionConv
     PCUICParallelReductionConfluence PCUICConfluence
     PCUICContextReduction PCUICOnFreeVars PCUICWellScopedCumulativity
     PCUICGuardCondition PCUICClosedTyp PCUICContextConversion.

From MetaCoq.PCUIC Require Export PCUICContextRelation.

From Coq Require Import CRelationClasses ssreflect ssrbool.
From Equations Require Import Equations.

Arguments red_ctx : clear implicits.

Implicit Types (cf : checker_flags) (Σ : global_env_ext).

Lemma weakening_cumulSpec0 {cf:checker_flags} {Σ} {wfΣ : wf Σ} {Γ : closed_context} {Γ'' : open_context Γ}
  {M N : open_term Γ} n :
  n = #|Γ''| ->
  Σ ;;; Γ |- M <=s N ->
  Σ ;;; Γ ,,, Γ'' |- lift0 n M <=s lift0 n N.
  Admitted.

Lemma split_closed_context {Γ : context} (n : nat) : 
  is_closed_context Γ ->
  n <= #|Γ| ->
  ∑ (Δ : closed_context) (Δ' : open_context Δ), 
    [× Δ = skipn n Γ :> context, Δ' = firstn n Γ :> context,
       Γ = Δ ,,, Δ' & n = #|Δ'|].
Proof.
  rewrite -{1}(firstn_skipn n Γ).
  rewrite on_free_vars_ctx_app => /andP[] sk fi.
  exists (exist (skipn n Γ) sk).
  exists (exist (firstn n Γ) fi). split; auto.
  cbn. now rewrite firstn_skipn. cbn.
  rewrite List.firstn_length. lia.
Qed.

Lemma nth_error_closed_context {Γ n d} :
  is_closed_context Γ ->  
  nth_error Γ n = Some d ->
  ws_decl (skipn (S n) Γ) d.
Proof.
  rewrite -on_free_vars_ctx_on_ctx_free_vars -[shiftnP _ _]addnP0 => hΔ' hnth.
  eapply nth_error_on_free_vars_ctx in hΔ'; tea.
  2:{ rewrite /shiftnP /= orb_false_r. apply Nat.ltb_lt. now apply nth_error_Some_length in hnth. }
  rewrite List.skipn_length.
  eapply on_free_vars_decl_impl; tea.
  intros i.
  rewrite /= /addnP /shiftnP /= !orb_false_r => /Nat.ltb_lt hl.
  apply Nat.ltb_lt. lia.
Qed.

Lemma on_free_vars_decl_lift (p : nat -> bool) n k t : 
  on_free_vars_decl (strengthenP k n p) (lift_decl n k t) = on_free_vars_decl p t.
Proof.
  rewrite /on_free_vars_decl /test_decl /=.
  f_equal. destruct (decl_body t) => /= //.
  all:now rewrite on_free_vars_lift.
Qed.

Lemma on_free_vars_decl_lift_impl (p : nat -> bool) n k d : 
  on_free_vars_decl (shiftnP k p) d ->
  on_free_vars_decl (shiftnP (n + k) p) (lift_decl n k d).
Proof.
  rewrite /on_free_vars_decl /test_decl /= => /andP[].
  destruct (decl_body d) => /= //.
  move/(on_free_vars_lift_impl _ n) ->.
  move/(on_free_vars_lift_impl _ n) -> => //.
  move=> _.
  move/(on_free_vars_lift_impl _ n) -> => //.
Qed.

Lemma nth_error_Some_add {A} (l : list A) (n : nat) (x : A) : 
  (nth_error l n = Some x) <~> 
  (n < #|l| × nth_error l n = Some x).
Proof.
  split. intros hnth; split => //.
  now eapply nth_error_Some_length in hnth.
  now intros [].
Qed.

Lemma nth_error_closed_context_lift {Γ n d} :
  is_closed_context Γ ->  
  nth_error Γ n = Some d ->
  ws_decl Γ (lift_decl (S n) 0 d).
Proof.
  move=> cl /nth_error_Some_add[] hn /(nth_error_closed_context cl).
  rewrite -(on_free_vars_decl_lift _ (S n) 0 d).
  apply: on_free_vars_decl_impl => i.
  rewrite /strengthenP /= /shiftnP !orb_false_r List.skipn_length.
  repeat PCUICSigmaCalculus.nat_compare_specs => //.
Qed.

Lemma wt_cum_equality {cf} {Σ} {wfΣ : wf Σ} {Γ : context} {t A B : term} {s} :
  Σ ;;; Γ |- t : A ->
  Σ ;;; Γ |- B : tSort s ->
  Σ ;;; Γ |- A <= B ->
  Σ ;;; Γ ⊢ A ≤ B. 
Proof.
  move=> a; move: a (typing_wf_local a).
  move/PCUICClosedTyp.type_closed/(@closedn_on_free_vars xpred0) => clA.
  move/wf_local_closed_context => clΓ.
  move/PCUICClosedTyp.subject_closed/(@closedn_on_free_vars xpred0) => clB cum.
  now apply into_equality.
Qed.

Lemma wt_cum_context_equality {cf} {Σ} {wfΣ : wf Σ} {Γ Δ : context} le :
  wf_local Σ Γ ->
  wf_local Σ Δ ->
  (if le then cumul_context Σ Γ Δ else conv_context Σ Γ Δ) ->
  Σ ⊢ Γ ≤[le] Δ. 
Proof.
  move/wf_local_closed_context => wfΓ.
  move/wf_local_closed_context => wfΔ.
  now eapply into_context_equality.
Qed.

Lemma All2_conv_over_refl {cf} {Σ} {Γ Γ' Δ} : 
  All2_fold (All_over (conv_decls Σ) Γ Γ') Δ Δ.
Proof.
  eapply All2_fold_refl. intros ? ?; reflexivity.
Qed.

Lemma All2_cumul_over_refl {cf} {Σ} {Γ Γ' Δ} : 
  All2_fold (All_over (cumul_decls Σ) Γ Γ') Δ Δ.
Proof.
  eapply All2_fold_refl. intros ? ?; reflexivity.
Qed.

Lemma context_cumulativity_prop {cf:checker_flags} :
  env_prop
    (fun Σ Γ t T =>
       forall Γ', cumul_context Σ Γ' Γ -> wf_local Σ Γ' -> Σ ;;; Γ' |- t : T)
    (fun Σ Γ => 
    All_local_env
      (lift_typing (fun Σ (Γ : context) (t T : term) =>
        forall Γ' : context, cumul_context Σ Γ' Γ -> wf_local Σ Γ' -> Σ;;; Γ' |- t : T) Σ) Γ).
(* Proof.
  apply typing_ind_env; intros Σ wfΣ Γ wfΓ; intros **; rename_all_hyps;
    try solve [econstructor; eauto].

  - induction X; constructor; auto.
    destruct tu as [s Hs]. exists s; eauto.
    destruct tu as [s Hs]. exists s; eauto.

  - pose proof heq_nth_error.
    eapply (All2_fold_nth_r X0) in H as [d' [Hnth [Hrel Hconv]]].
    unshelve eapply nth_error_All_local_env in X; tea. 2:eapply nth_error_Some_length in heq_nth_error; lia.
    rewrite heq_nth_error /= in X.
    destruct decl as [na [b|] ty] => /=.
    + red in X. cbn in X. destruct X as [Hb Hty].
      destruct Hty as [s Hty]. specialize (Hty _ Hrel).
      forward Hty by now eapply All_local_env_skipn.
      eapply type_Cumul with _ s.
      * econstructor. auto. eauto.
      * rewrite -(firstn_skipn (S n) Γ').
        change (tSort s) with (lift0 (S n) (tSort s)).
        eapply weakening_length. auto.
        rewrite firstn_length_le. eapply nth_error_Some_length in Hnth. lia. auto.
        now rewrite /app_context firstn_skipn.
        assumption.
      * depelim Hconv; simpl in *.
        destruct (split_closed_context (S n) (wf_local_closed_context X1)) as [Δ [Δ' [eqΔ eqΔ' -> hn]]].
        eapply nth_error_Some_length in Hnth. lia.
        rewrite -eqΔ in Hty, Hrel.
        rewrite -eqΔ in c0, c.
        assert (is_open_term Δ T).
        { eapply nth_error_closed_context in Hnth. 2:eauto with fvs.
          rewrite -eqΔ in Hnth. now move/andP: Hnth => []. }
        eapply PCUICClosedTyp.subject_closed in Hty.
        eapply (@closedn_on_free_vars xpred0) in Hty.
        eapply (weakening_cumulSpec0 (Γ := Δ) (Γ'' := Δ') (M := exist T H) (N := exist ty Hty)); cbn. lia.
        exact c0.
    + cbn in X. destruct X as [s ondecl].
      specialize (ondecl _ Hrel).
      depelim Hconv.
      forward ondecl by now eapply All_local_env_skipn.
      eapply type_Cumul with _ s.
      * econstructor. auto. eauto.
      * rewrite -(firstn_skipn (S n) Γ').
        change (tSort s) with (lift0 (S n) (tSort s)).
        eapply weakening_length. auto.
        rewrite firstn_length_le. eapply nth_error_Some_length in Hnth. lia. auto.
        now rewrite /app_context firstn_skipn.
        assumption.
      * destruct (split_closed_context (S n) (wf_local_closed_context X1)) as [Δ [Δ' [eqΔ eqΔ' -> hn]]].
        eapply nth_error_Some_length in Hnth. lia.
        rewrite -eqΔ in ondecl, Hrel.
        rewrite -eqΔ in c.
        assert (is_open_term Δ T).
        { rewrite nth_error_app_lt in Hnth. rewrite -hn. lia.
          destruct Δ' as [Δ' hΔ']. cbn in *.
          move: hΔ'.
          rewrite -on_free_vars_ctx_on_ctx_free_vars -[shiftnP _ _]addnP0 => hΔ'.
          eapply nth_error_on_free_vars_ctx in hΔ'; tea.
          2:{ rewrite shiftnP_add /shiftnP /= orb_false_r. apply Nat.ltb_lt. lia. }
          rewrite /test_decl /= in hΔ'. move: hΔ'.
          now rewrite hn addnP_shiftnP. }
        eapply PCUICClosedTyp.subject_closed in ondecl.
        eapply (@closedn_on_free_vars xpred0) in ondecl.
        eapply (weakening_cumulSpec0 (Γ := Δ) (Γ'' := Δ') (M := exist T H) (N := exist ty ondecl)); cbn. lia.
        exact c.
  - constructor; pcuic.
    eapply forall_Γ'0. repeat (constructor; pcuic).
    constructor; auto. red. eexists; eapply forall_Γ'; auto.
  - econstructor; pcuic.
    eapply forall_Γ'0; repeat (constructor; pcuic).
  - econstructor; pcuic.
    eapply forall_Γ'1; repeat (constructor; pcuic).
  - econstructor; eauto.
    * eapply context_cumulativity_wf_app; tea.
    * eapply IHp0. rewrite /predctx.
      eapply All2_fold_app => //.
      eapply All2_fold_refl. intros ? ?; reflexivity.
      eapply context_cumulativity_wf_app; tea.
    * revert X6.
      clear -Γ' X10 X11. induction 1; constructor; eauto.
    * eapply All2i_impl; tea => i cdecl br. cbv beta.
      set (brctxty := case_branch_type _ _ _ _ _ _ _ _). cbn.
      move=> [] hbctx [] ihbctxty [] hbody [] IHbody [] hbty IHbty.
      intuition eauto; solve_all.
      eapply context_cumulativity_wf_app; tea.
      eapply IHbody. eapply All2_fold_app => //. apply All2_cumul_over_refl.
      eauto using context_cumulativity_app, context_cumulativity_wf_app.
      eapply IHbty.
      eapply All2_fold_app => //. apply All2_cumul_over_refl.
      eapply context_cumulativity_wf_app; tea.
  - econstructor. eapply fix_guard_context_cumulativity; eauto.
    all:pcuic.
    eapply (All_impl X0).
    intros x [s [Hs IH]].
    exists s; eauto.
    eapply (All_impl X1).
    intros x [Hs IH].
    eapply IH.
    now apply cumul_context_app_same.
    eapply (All_mfix_wf); auto.
    apply (All_impl X0); simpl.
    intros x' [s [Hs' IH']]. exists s.
    eapply IH'; auto.
  - econstructor.
    eapply cofix_guard_context_cumulativity; eauto.
    all:pcuic.
    + eapply (All_impl X0).
      intros x [s [Hs IH]].
      exists s; eauto.
    + eapply (All_impl X1).
      intros x [Hs IH].
      eapply IH.
      now apply cumul_context_app_same.
      eapply (All_mfix_wf); auto.
      apply (All_impl X0); simpl.
      intros x' [s [Hs' IH']]. exists s.
      eapply IH'; auto.
    
  - econstructor; eauto.
    eapply wt_cum_equality in X4; tea.
    apply (wt_cum_context_equality true) in X5; tea.
    eapply (equality_equality_ctx X5) in X4.
    now eapply equality_forget in X4. 
Qed. *)
Admitted.

Lemma closed_context_cumul_cumul {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  Σ ⊢ Γ ≤ Γ' -> cumul_context Σ Γ Γ'.
Proof.
  now move/context_equality_forget.
Qed.
#[global] Hint Resolve closed_context_cumul_cumul : pcuic.

Lemma closed_context_conv_conv {cf} {Σ} {wfΣ : wf Σ} {Γ Γ'} : 
  Σ ⊢ Γ = Γ' -> conv_context Σ Γ Γ'.
Proof.
  now move/context_equality_forget.
Qed.
#[global] Hint Resolve closed_context_conv_conv : pcuic.

Lemma closed_context_cumulativity {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {le t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  Σ ⊢ Γ' ≤[le] Γ ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  pose proof (context_equality_forget e).
  destruct le.
  eapply context_cumulativity_prop; eauto.
  eapply context_cumulativity_prop; eauto.
  eapply conv_cumul_context in e; tea.
  eapply (context_equality_forget e).
Qed.

Lemma context_cumulativity {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  cumul_context Σ Γ' Γ ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  eapply context_cumulativity_prop; eauto.
Qed.

#[global] Hint Resolve wf_local_closed_context : fvs.

Lemma wf_conv_context_closed {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} {Γ Γ'} :
  conv_context Σ Γ Γ' -> 
  wf_local Σ Γ ->
  wf_local Σ Γ' ->
  context_equality false Σ Γ Γ'.
Proof.
  move=> a wf wf'.
  eapply into_context_equality; eauto with fvs.
Qed.

Lemma wf_cumul_context_closed {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} {Γ Γ'} :
  cumul_context Σ Γ Γ' -> 
  wf_local Σ Γ ->
  wf_local Σ Γ' ->
  context_equality true Σ Γ Γ'.
Proof.
  move=> a wf wf'.
  eapply into_context_equality; eauto with fvs.
Qed.

Lemma context_conversion {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  conv_context Σ Γ Γ' ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  eapply wf_conv_context_closed in e; eauto with fvs pcuic.
  symmetry in e.
  now eapply closed_context_cumulativity in e.
Qed.

(* For ease of application, avoiding to add a call to symmetry *)
Lemma closed_context_conversion {cf:checker_flags} {Σ} {wfΣ : wf Σ.1} Γ {t T Γ'} :
  Σ ;;; Γ |- t : T ->
  wf_local Σ Γ' ->
  Σ ⊢ Γ = Γ' ->
  Σ ;;; Γ' |- t : T.
Proof.
  intros h hΓ' e.
  symmetry in e.
  now eapply closed_context_cumulativity in e.
Qed.
