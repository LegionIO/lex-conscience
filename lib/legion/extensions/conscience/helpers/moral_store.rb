# frozen_string_literal: true

module Legion
  module Extensions
    module Conscience
      module Helpers
        class MoralStore
          attr_reader :evaluator, :history, :dilemmas, :sensitivity_snapshots

          def initialize(evaluator: nil)
            @evaluator            = evaluator || MoralEvaluator.new
            @history              = []
            @dilemmas             = []
            @sensitivity_snapshots = []
            @followed_count       = 0
            @overridden_count     = 0
          end

          # Store a completed moral evaluation result
          def record_evaluation(result)
            @history << result
            @history.shift while @history.size > Constants::MAX_MORAL_HISTORY

            @dilemmas << result[:dilemma] if result[:dilemma]

            snapshot_sensitivities(result[:verdict])

            result
          end

          # Record whether the agent followed its moral verdict or overrode it.
          # outcome: :followed | :overridden
          def record_follow_through(verdict, outcome)
            if outcome == :followed
              @followed_count += 1
            else
              @overridden_count += 1
            end

            # Feed back into evaluator sensitivities
            foundation_feedback(verdict, outcome)
          end

          # Ratio of evaluations where the agent followed its moral verdict
          def consistency_score
            total = @followed_count + @overridden_count
            return 1.0 if total.zero?

            (@followed_count.to_f / total).round(4)
          end

          # Current foundation sensitivities from the evaluator
          def foundation_sensitivities
            @evaluator.sensitivities.transform_values { |s| s.round(4) }
          end

          # Recent evaluations, newest last
          def recent_evaluations(limit = 20)
            @history.last(limit)
          end

          # Open dilemmas (not yet resolved)
          def open_dilemmas
            @dilemmas.last(20)
          end

          # Aggregate stats across all evaluations
          def aggregate_stats
            verdict_counts = Hash.new(0)
            @history.each { |e| verdict_counts[e[:verdict]] += 1 }

            {
              total_evaluations:        @history.size,
              verdict_counts:           verdict_counts,
              dilemma_count:            @dilemmas.size,
              consistency_score:        consistency_score,
              followed_count:           @followed_count,
              overridden_count:         @overridden_count,
              foundation_sensitivities: foundation_sensitivities
            }
          end

          private

          def snapshot_sensitivities(verdict)
            @sensitivity_snapshots << {
              verdict:       verdict,
              sensitivities: @evaluator.sensitivities.dup,
              at:            Time.now.utc
            }
            @sensitivity_snapshots.shift while @sensitivity_snapshots.size > Constants::MAX_MORAL_HISTORY
          end

          def foundation_feedback(verdict, outcome)
            # When an agent overrides a prohibited verdict, desensitize authority/sanctity
            # When an agent follows a cautioned verdict, sensitize care/fairness
            case [verdict, outcome]
            when %i[prohibited overridden]
              @evaluator.update_sensitivity(:care, -0.5)
              @evaluator.update_sensitivity(:sanctity, -0.3)
            when %i[cautioned followed]
              @evaluator.update_sensitivity(:care, 0.8)
              @evaluator.update_sensitivity(:fairness, 0.6)
            when %i[permitted followed]
              @evaluator.update_sensitivity(:liberty, 0.7)
            end
          end
        end
      end
    end
  end
end
