# frozen_string_literal: true

module Legion
  module Extensions
    module Conscience
      module Helpers
        class MoralEvaluator
          attr_reader :sensitivities

          def initialize
            @sensitivities = Constants::MORAL_FOUNDATIONS.keys.to_h do |foundation|
              [foundation, Constants::INITIAL_SENSITIVITY]
            end
          end

          # Evaluate a proposed action against all 6 moral foundations.
          # Returns a hash with per-foundation scores, weighted_score, verdict, and dilemma info.
          def evaluate(action:, context:)
            scores = per_foundation_scores(action, context)
            w_score = weighted_score(scores)
            v = verdict(w_score)
            dilemma = detect_dilemma(scores)

            {
              action:         action,
              scores:         scores,
              weighted_score: w_score.round(4),
              verdict:        v,
              dilemma:        dilemma,
              sensitivities:  @sensitivities.transform_values { |s| s.round(4) },
              evaluated_at:   Time.now.utc
            }
          end

          # Weighted sum of per-foundation scores * weights * sensitivity
          def weighted_score(scores)
            total = 0.0
            Constants::MORAL_FOUNDATIONS.each do |foundation, config|
              score = scores[foundation] || 0.0
              sensitivity = @sensitivities[foundation]
              total += score * config[:weight] * sensitivity
            end
            total.clamp(Constants::MORAL_SCORE_RANGE[:min], Constants::MORAL_SCORE_RANGE[:max])
          end

          # Determine overall moral verdict from a weighted score
          def verdict(score)
            if score <= Constants::PROHIBITION_THRESHOLD
              :prohibited
            elsif score < Constants::CAUTION_THRESHOLD
              :cautioned
            else
              :permitted
            end
          end

          # Detect a dilemma when foundations strongly disagree with each other.
          # Returns nil when no dilemma, or a hash describing the conflict type and disagreeing foundations.
          def detect_dilemma(scores)
            pos_foundations = scores.select { |_, v| v > Constants::CONFLICT_THRESHOLD }
            neg_foundations = scores.select { |_, v| v < -Constants::CONFLICT_THRESHOLD }

            return nil if pos_foundations.empty? || neg_foundations.empty?

            dilemma_type = classify_dilemma(pos_foundations.keys, neg_foundations.keys)

            {
              type:            dilemma_type,
              approving:       pos_foundations.keys,
              opposing:        neg_foundations.keys,
              tension:         (pos_foundations.values.sum / pos_foundations.size.to_f).round(4),
              counter_tension: (neg_foundations.values.sum / neg_foundations.size.to_f).abs.round(4),
              detected_at:     Time.now.utc
            }
          end

          # Feedback loop: update sensitivity for a foundation based on observed outcome.
          # outcome is a float in [-1.0, 1.0] where positive = action was morally good in retrospect.
          def update_sensitivity(foundation, outcome)
            return unless @sensitivities.key?(foundation)

            current = @sensitivities[foundation]
            @sensitivities[foundation] = ema(current, outcome.abs.clamp(0.0, 1.0), Constants::FOUNDATION_ALPHA)
          end

          private

          def per_foundation_scores(action, context)
            {
              care:      evaluate_care(action, context),
              fairness:  evaluate_fairness(action, context),
              loyalty:   evaluate_loyalty(action, context),
              authority: evaluate_authority(action, context),
              sanctity:  evaluate_sanctity(action, context),
              liberty:   evaluate_liberty(action, context)
            }
          end

          # Care/Harm — compassion axis
          # harm_to_others: negative, benefit_to_others: positive
          def evaluate_care(_action, context)
            harm  = context.fetch(:harm_to_others, 0.0).to_f.clamp(-1.0, 1.0)
            benef = context.fetch(:benefit_to_others, 0.0).to_f.clamp(-1.0, 1.0)
            vuln  = context.fetch(:vulnerable_affected, false) ? -0.2 : 0.0

            score = (benef - harm.abs) + vuln
            score.clamp(-1.0, 1.0)
          end

          # Fairness/Cheating — justice axis
          # distributional_justice, reciprocity, proportionality
          def evaluate_fairness(_action, context)
            justice        = context.fetch(:distributional_justice, 0.0).to_f.clamp(-1.0, 1.0)
            reciprocity    = context.fetch(:reciprocity, 0.0).to_f.clamp(-1.0, 1.0)
            proportional   = context.fetch(:proportionality, 0.0).to_f.clamp(-1.0, 1.0)

            ((justice + reciprocity + proportional) / 3.0).clamp(-1.0, 1.0)
          end

          # Loyalty/Betrayal — group allegiance axis
          def evaluate_loyalty(_action, context)
            alignment  = context.fetch(:alignment_with_group_norms, 0.0).to_f.clamp(-1.0, 1.0)
            trust_pres = context.fetch(:trust_preservation, 0.0).to_f.clamp(-1.0, 1.0)

            ((alignment + trust_pres) / 2.0).clamp(-1.0, 1.0)
          end

          # Authority/Subversion — hierarchy respect axis
          def evaluate_authority(_action, context)
            compliance = context.fetch(:legitimate_authority_compliance, 0.0).to_f.clamp(-1.0, 1.0)
            hierarchy  = context.fetch(:hierarchy_respect, 0.0).to_f.clamp(-1.0, 1.0)

            ((compliance + hierarchy) / 2.0).clamp(-1.0, 1.0)
          end

          # Sanctity/Degradation — system integrity axis
          def evaluate_sanctity(_action, context)
            integrity = context.fetch(:system_integrity, 0.0).to_f.clamp(-1.0, 1.0)
            degrad    = context.fetch(:degradation_prevention, 0.0).to_f.clamp(-1.0, 1.0)

            ((integrity + degrad) / 2.0).clamp(-1.0, 1.0)
          end

          # Liberty/Oppression — autonomy axis
          def evaluate_liberty(_action, context)
            autonomy = context.fetch(:autonomy_preservation, 0.0).to_f.clamp(-1.0, 1.0)
            consent  = context.fetch(:consent_present, false) ? 0.3 : -0.2

            (autonomy + consent).clamp(-1.0, 1.0)
          end

          # Classify the dilemma type from which foundations are in conflict
          def classify_dilemma(approving, opposing)
            care_side    = approving.include?(:care) || opposing.include?(:care)
            fair_side    = approving.include?(:fairness) || opposing.include?(:fairness)
            auth_side    = approving.include?(:authority) || opposing.include?(:authority)

            if care_side && fair_side
              :utilitarian
            elsif auth_side
              :deontological
            else
              :virtue_ethics
            end
          end

          def ema(current, observed, alpha)
            (current * (1.0 - alpha)) + (observed * alpha)
          end
        end
      end
    end
  end
end
