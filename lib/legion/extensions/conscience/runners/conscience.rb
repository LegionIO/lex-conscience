# frozen_string_literal: true

module Legion
  module Extensions
    module Conscience
      module Runners
        module Conscience
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          # Full moral assessment of a proposed action.
          # action: string or symbol describing what is about to happen
          # context: hash of moral context signals (harm_to_others, consent_present, etc.)
          def moral_evaluate(action:, context: {}, **)
            result = moral_store.evaluator.evaluate(action: action, context: context)
            moral_store.record_evaluation(result)

            Legion::Logging.debug "[conscience] action=#{action} verdict=#{result[:verdict]} " \
                                  "score=#{result[:weighted_score]} dilemma=#{result[:dilemma]&.dig(:type)}"

            result
          end

          # Current moral sensitivities and consistency score
          def moral_status(**)
            stats = moral_store.aggregate_stats
            sensitivities = moral_store.foundation_sensitivities

            Legion::Logging.debug "[conscience] consistency=#{stats[:consistency_score]} " \
                                  "evaluations=#{stats[:total_evaluations]}"

            {
              sensitivities: sensitivities,
              consistency:   stats[:consistency_score],
              stats:         stats
            }
          end

          # Recent moral evaluation history
          def moral_history(limit: 20, **)
            recent = moral_store.recent_evaluations(limit)
            Legion::Logging.debug "[conscience] history: #{recent.size} entries"

            {
              history: recent,
              total:   moral_store.history.size,
              limit:   limit
            }
          end

          # Record whether the agent actually followed or overrode its moral verdict.
          # outcome: :followed | :overridden
          def update_moral_outcome(action:, outcome:, verdict: nil, **)
            effective_verdict = verdict || infer_last_verdict(action)

            moral_store.record_follow_through(effective_verdict, outcome)

            Legion::Logging.debug "[conscience] follow_through action=#{action} " \
                                  "verdict=#{effective_verdict} outcome=#{outcome} " \
                                  "consistency=#{moral_store.consistency_score}"

            {
              action:      action,
              verdict:     effective_verdict,
              outcome:     outcome,
              consistency: moral_store.consistency_score
            }
          end

          # List unresolved moral dilemmas (cases where foundations strongly disagreed)
          def moral_dilemmas(**)
            open = moral_store.open_dilemmas
            Legion::Logging.debug "[conscience] dilemmas: #{open.size} open"

            {
              dilemmas: open,
              count:    open.size
            }
          end

          # Aggregate moral reasoning stats
          def conscience_stats(**)
            stats = moral_store.aggregate_stats
            Legion::Logging.debug '[conscience] stats'

            stats.merge(
              verdict_distribution: verdict_distribution(stats[:verdict_counts]),
              foundation_weights:   Helpers::Constants::MORAL_FOUNDATIONS.transform_values { |v| v[:weight] }
            )
          end

          private

          def moral_store
            @moral_store ||= Helpers::MoralStore.new
          end

          def infer_last_verdict(action)
            last = moral_store.history.reverse.find { |e| e[:action] == action }
            last ? last[:verdict] : :permitted
          end

          def verdict_distribution(verdict_counts)
            total = verdict_counts.values.sum.to_f
            return {} if total.zero?

            verdict_counts.transform_values { |count| (count / total).round(4) }
          end
        end
      end
    end
  end
end
