# lex-conscience

A LegionIO cognitive architecture extension implementing Moral Foundations Theory (Haidt & Graham, 2007). Before an agent takes an action, conscience evaluates it across six moral foundations — Care, Fairness, Loyalty, Authority, Sanctity, and Liberty — and issues a verdict. Foundation sensitivities evolve over time based on whether the agent follows or overrides its own moral judgments.

## What It Does

Evaluates proposed actions using six moral foundations, each scored from context signals and combined via weighted sum into a verdict:

- **Permitted** — weighted moral score >= -0.1; action is morally acceptable
- **Cautioned** — score between -0.5 and -0.1; proceed with care
- **Prohibited** — score <= -0.5; action should be blocked

When foundations strongly disagree (scores diverge by more than 0.3), a **dilemma** is detected and classified as utilitarian, deontological, or virtue-ethics. The agent can record whether it followed or overrode a verdict, feeding back into foundation sensitivity via EMA.

## Usage

```ruby
require 'lex-conscience'

client = Legion::Extensions::Conscience::Client.new

# Evaluate a proposed action
result = client.moral_evaluate(
  action:  'delete_user_data',
  context: {
    harm_to_others:         0.7,
    benefit_to_others:      0.0,
    vulnerable_affected:    true,
    consent_present:        false,
    autonomy_preservation: -0.5,
    system_integrity:       0.2
  }
)
# => { action: "delete_user_data", verdict: :prohibited,
#      weighted_score: -0.62, dilemma: nil,
#      scores: { care: -0.9, fairness: 0.0, loyalty: 0.0,
#                authority: 0.0, sanctity: 0.1, liberty: -0.7 },
#      sensitivities: { care: 1.0, fairness: 1.0, ... }, evaluated_at: ... }

# Record whether the agent followed its verdict
client.update_moral_outcome(
  action:  'delete_user_data',
  outcome: :followed   # or :overridden
)
# => { action: "delete_user_data", verdict: :prohibited,
#      outcome: :followed, consistency: 1.0 }

# Current sensitivities and consistency score
client.moral_status
# => { sensitivities: { care: 1.0, ... }, consistency: 1.0, stats: { ... } }

# Recent evaluation history
client.moral_history(limit: 10)
# => { history: [...], total: 1, limit: 10 }

# Open moral dilemmas (cases where foundations strongly disagreed)
client.moral_dilemmas
# => { dilemmas: [], count: 0 }

# Aggregate stats
client.conscience_stats
# => { total_evaluations: 1, verdict_counts: { prohibited: 1 },
#      dilemma_count: 0, consistency_score: 1.0,
#      verdict_distribution: { prohibited: 1.0 },
#      foundation_weights: { care: 0.25, fairness: 0.20, ... } }
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
