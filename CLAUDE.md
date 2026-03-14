# lex-conscience

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Applies Moral Foundations Theory (Haidt & Graham, 2007) to evaluate proposed actions before execution, track moral consistency, and surface ethical dilemmas. Six moral foundations — Care, Fairness, Loyalty, Authority, Sanctity, and Liberty — each score an action in context and are combined via weighted sum to produce a verdict. Foundation sensitivities adjust via EMA over time based on whether the agent follows or overrides its moral verdicts.

## Gem Info

- **Gem name**: `legion-extensions-conscience`
- **Version**: `0.1.0`
- **Module**: `Legion::Extensions::Conscience`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/conscience/
  version.rb
  helpers/
    constants.rb          # Moral foundations, verdicts, thresholds, sensitivity constants
    moral_evaluator.rb    # MoralEvaluator — per-foundation scoring and dilemma detection
    moral_store.rb        # MoralStore — evaluation history, follow-through tracking, consistency
  runners/
    conscience.rb         # Runner module — public API
  client.rb
```

## Key Constants

| Constant | Value | Meaning |
|---|---|---|
| `FOUNDATION_ALPHA` | 0.05 | EMA alpha for sensitivity updates — very slow adaptation |
| `CONFLICT_THRESHOLD` | 0.3 | Foundation scores must exceed +/- this to trigger a dilemma |
| `PROHIBITION_THRESHOLD` | -0.5 | Weighted score at or below this = `:prohibited` verdict |
| `CAUTION_THRESHOLD` | -0.1 | Weighted score below this (but above prohibition) = `:cautioned` verdict |
| `MAX_MORAL_HISTORY` | 100 | Ring buffer for evaluation history and sensitivity snapshots |
| `INITIAL_SENSITIVITY` | 1.0 | Each foundation starts fully sensitive |

`MORAL_VERDICTS`: `[:permitted, :cautioned, :conflicted, :prohibited]`

`MORAL_FOUNDATIONS` with weights:
- `care: 0.25` — compassion and prevention of suffering
- `fairness: 0.20` — justice, reciprocity, proportionality
- `loyalty: 0.15` — group allegiance and trustworthiness
- `authority: 0.15` — respect for hierarchy and legitimate authority
- `sanctity: 0.15` — purity and integrity of systems
- `liberty: 0.10` — autonomy and freedom from domination

`DILEMMA_TYPES`: `[:utilitarian, :deontological, :virtue_ethics]`

## Key Classes

### `Helpers::MoralEvaluator`

Scores a proposed action against all six foundations using context signals.

- `evaluate(action:, context:)` — returns `{ action:, scores:, weighted_score:, verdict:, dilemma:, sensitivities:, evaluated_at: }`
- `weighted_score(scores)` — sum of `score * weight * sensitivity` across all foundations; clamped to `[-1.0, 1.0]`
- `verdict(score)` — `:prohibited` if score <= -0.5; `:cautioned` if score < -0.1; `:permitted` otherwise
- `detect_dilemma(scores)` — returns nil or `{ type:, approving:, opposing:, tension:, counter_tension:, detected_at: }` when foundations strongly disagree
- `update_sensitivity(foundation, outcome)` — EMA update at alpha 0.05; `outcome` is `[-1.0, 1.0]`

Per-foundation context keys:
- `care`: `harm_to_others`, `benefit_to_others`, `vulnerable_affected`
- `fairness`: `distributional_justice`, `reciprocity`, `proportionality`
- `loyalty`: `alignment_with_group_norms`, `trust_preservation`
- `authority`: `legitimate_authority_compliance`, `hierarchy_respect`
- `sanctity`: `system_integrity`, `degradation_prevention`
- `liberty`: `autonomy_preservation`, `consent_present`

Dilemma classification: care + fairness in conflict = `:utilitarian`; authority involved = `:deontological`; otherwise = `:virtue_ethics`

### `Helpers::MoralStore`

Stores evaluation history and tracks follow-through consistency.

- `record_evaluation(result)` — appends to history (ring buffer at 100); appends dilemma if present; snapshots sensitivities
- `record_follow_through(verdict, outcome)` — `:followed` or `:overridden`; triggers sensitivity feedback: overriding `:prohibited` desensitizes care/sanctity; following `:cautioned` sensitizes care/fairness; following `:permitted` sensitizes liberty
- `consistency_score` — ratio of followed to total follow-through events
- `foundation_sensitivities` — current sensitivity values from evaluator
- `recent_evaluations(limit)` — last N evaluations
- `open_dilemmas` — last 20 detected dilemmas
- `aggregate_stats` — `{ total_evaluations:, verdict_counts:, dilemma_count:, consistency_score:, followed_count:, overridden_count:, foundation_sensitivities: }`

## Runners

Module: `Legion::Extensions::Conscience::Runners::Conscience`

| Runner | Key Args | Returns |
|---|---|---|
| `moral_evaluate` | `action:`, `context: {}` | Full evaluation result hash (scores, verdict, dilemma, sensitivities) |
| `moral_status` | — | `{ sensitivities:, consistency:, stats: }` |
| `moral_history` | `limit: 20` | `{ history:, total:, limit: }` |
| `update_moral_outcome` | `action:`, `outcome:`, `verdict: nil` | `{ action:, verdict:, outcome:, consistency: }` |
| `moral_dilemmas` | — | `{ dilemmas:, count: }` |
| `conscience_stats` | — | aggregate_stats + `verdict_distribution:` + `foundation_weights:` |

`update_moral_outcome` infers the most recent verdict for the action from history when `verdict:` is not provided.

## Integration Points

- `moral_evaluate` is the pre-action gate — called in `lex-tick`'s `action_selection` phase
- `update_moral_outcome` closes the feedback loop after action execution
- `:prohibited` verdict should block action execution; `:cautioned` should require consent elevation
- `consistency_score` from `moral_status` reflects long-term moral integrity — low consistency indicates the agent frequently overrides its own ethical judgment
- Sensitivity drift over time reflects learned moral experience — heavily-violated foundations become desensitized
- Pairs with `lex-consent`: consent tier can be gated on verdict (`:prohibited` actions require explicit human approval)

## Development Notes

- Gemspec name is `legion-extensions-conscience` (not `lex-conscience`) — unusual within the ecosystem where most gems use `lex-` prefix
- `moral_evaluate` returns the raw evaluation hash, not a `{ success: }` wrapper
- `verdict` returns only `:permitted`, `:cautioned`, or `:prohibited` from the evaluator; `:conflicted` is defined in `MORAL_VERDICTS` but is not returned by the evaluator logic — it is a reserved label for future use
- `detect_dilemma` uses strict `>` and `<` comparisons against `CONFLICT_THRESHOLD` (0.3), not `>=`
- Sensitivity feedback is asymmetric: overriding a prohibited verdict desensitizes, following a cautioned verdict sensitizes — this models habituation and moral growth
- `infer_last_verdict` scans history in reverse for the same action string — if no match found, defaults to `:permitted`
