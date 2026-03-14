# frozen_string_literal: true

module Legion
  module Extensions
    module Conscience
      module Helpers
        module Constants
          # Moral Foundations Theory — 6 foundations with weights summing to 1.0
          # Based on Haidt & Graham (2007): Care, Fairness, Loyalty, Authority, Sanctity, Liberty
          MORAL_FOUNDATIONS = {
            care:      { weight: 0.25, description: 'Compassion and prevention of suffering' },
            fairness:  { weight: 0.20, description: 'Justice, reciprocity, and proportionality' },
            loyalty:   { weight: 0.15, description: 'Group allegiance and trustworthiness' },
            authority: { weight: 0.15, description: 'Respect for hierarchy and legitimate authority' },
            sanctity:  { weight: 0.15, description: 'Purity and integrity of systems' },
            liberty:   { weight: 0.10, description: 'Autonomy and freedom from domination' }
          }.freeze

          # Possible verdict outcomes from moral evaluation
          MORAL_VERDICTS = %i[permitted cautioned conflicted prohibited].freeze

          # EMA alpha for moral sensitivity — changes very slowly
          FOUNDATION_ALPHA = 0.05

          # Foundations must disagree by more than this to trigger a dilemma
          CONFLICT_THRESHOLD = 0.3

          # Weighted moral score below this means prohibited
          PROHIBITION_THRESHOLD = -0.5

          # Weighted moral score below this means cautioned
          CAUTION_THRESHOLD = -0.1

          # Maximum moral evaluation history entries to retain
          MAX_MORAL_HISTORY = 100

          # Types of ethical dilemmas that can arise when foundations conflict
          DILEMMA_TYPES = %i[utilitarian deontological virtue_ethics].freeze

          # Initial sensitivity value for each foundation — starts fully sensitive, decays through experience
          INITIAL_SENSITIVITY = 1.0

          # Moral score range (per-foundation and weighted)
          MORAL_SCORE_RANGE = { min: -1.0, max: 1.0 }.freeze
        end
      end
    end
  end
end
