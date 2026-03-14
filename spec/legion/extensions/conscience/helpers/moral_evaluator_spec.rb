# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Conscience::Helpers::MoralEvaluator do
  subject(:evaluator) { described_class.new }

  let(:benign_context) do
    {
      harm_to_others:                  0.0,
      benefit_to_others:               0.8,
      vulnerable_affected:             false,
      distributional_justice:          0.7,
      reciprocity:                     0.6,
      proportionality:                 0.5,
      alignment_with_group_norms:      0.6,
      trust_preservation:              0.7,
      legitimate_authority_compliance: 0.5,
      hierarchy_respect:               0.4,
      system_integrity:                0.8,
      degradation_prevention:          0.7,
      autonomy_preservation:           0.6,
      consent_present:                 true
    }
  end

  let(:harmful_context) do
    {
      harm_to_others:                  0.9,
      benefit_to_others:               0.0,
      vulnerable_affected:             true,
      distributional_justice:          -0.8,
      reciprocity:                     -0.7,
      proportionality:                 -0.6,
      alignment_with_group_norms:      -0.5,
      trust_preservation:              -0.8,
      legitimate_authority_compliance: -0.6,
      hierarchy_respect:               -0.5,
      system_integrity:                -0.9,
      degradation_prevention:          -0.8,
      autonomy_preservation:           -0.7,
      consent_present:                 false
    }
  end

  let(:conflicted_context) do
    {
      # Care says yes (benefit present, low harm)
      harm_to_others:                  0.0,
      benefit_to_others:               0.8,
      # Fairness says no (unjust distribution)
      distributional_justice:          -0.7,
      reciprocity:                     -0.6,
      proportionality:                 -0.5,
      # Authority says no (violates hierarchy)
      legitimate_authority_compliance: -0.8,
      hierarchy_respect:               -0.6
    }
  end

  describe '#initialize' do
    it 'sets initial sensitivity to 1.0 for all foundations' do
      evaluator.sensitivities.each_value do |s|
        expect(s).to eq(1.0)
      end
    end

    it 'has a sensitivity for each of the 6 foundations' do
      expect(evaluator.sensitivities.keys).to contain_exactly(
        :care, :fairness, :loyalty, :authority, :sanctity, :liberty
      )
    end
  end

  describe '#evaluate' do
    it 'returns a hash with required keys' do
      result = evaluator.evaluate(action: :deploy_patch, context: benign_context)
      expect(result).to include(:action, :scores, :weighted_score, :verdict, :dilemma, :sensitivities, :evaluated_at)
    end

    it 'returns per-foundation scores for all 6 foundations' do
      result = evaluator.evaluate(action: :deploy_patch, context: benign_context)
      expect(result[:scores].keys).to contain_exactly(:care, :fairness, :loyalty, :authority, :sanctity, :liberty)
    end

    it 'gives a positive weighted_score for benign context' do
      result = evaluator.evaluate(action: :deploy_patch, context: benign_context)
      expect(result[:weighted_score]).to be > 0.0
    end

    it 'gives a negative weighted_score for harmful context' do
      result = evaluator.evaluate(action: :delete_data, context: harmful_context)
      expect(result[:weighted_score]).to be < 0.0
    end

    it 'returns :permitted verdict for benign context' do
      result = evaluator.evaluate(action: :deploy_patch, context: benign_context)
      expect(result[:verdict]).to eq(:permitted)
    end

    it 'returns :prohibited verdict for harmful context' do
      result = evaluator.evaluate(action: :delete_data, context: harmful_context)
      expect(result[:verdict]).to eq(:prohibited)
    end

    it 'weighted_score is within [-1.0, 1.0]' do
      result = evaluator.evaluate(action: :anything, context: harmful_context)
      expect(result[:weighted_score]).to be_between(-1.0, 1.0)
    end

    it 'includes evaluated_at timestamp' do
      result = evaluator.evaluate(action: :test, context: {})
      expect(result[:evaluated_at]).to be_a(Time)
    end

    it 'handles empty context without error' do
      expect { evaluator.evaluate(action: :test, context: {}) }.not_to raise_error
    end
  end

  describe '#weighted_score' do
    it 'returns a float in [-1.0, 1.0]' do
      scores = { care: 0.5, fairness: 0.3, loyalty: 0.2, authority: 0.1, sanctity: 0.4, liberty: 0.6 }
      score = evaluator.weighted_score(scores)
      expect(score).to be_a(Float)
      expect(score).to be_between(-1.0, 1.0)
    end

    it 'returns 0.0 for all-zero scores' do
      scores = { care: 0.0, fairness: 0.0, loyalty: 0.0, authority: 0.0, sanctity: 0.0, liberty: 0.0 }
      expect(evaluator.weighted_score(scores)).to eq(0.0)
    end

    it 'returns a positive value when all scores are positive' do
      scores = { care: 1.0, fairness: 1.0, loyalty: 1.0, authority: 1.0, sanctity: 1.0, liberty: 1.0 }
      expect(evaluator.weighted_score(scores)).to be > 0.0
    end
  end

  describe '#verdict' do
    it 'returns :prohibited for score below -0.5' do
      expect(evaluator.verdict(-0.6)).to eq(:prohibited)
    end

    it 'returns :prohibited for score at exactly -0.5' do
      expect(evaluator.verdict(-0.5)).to eq(:prohibited)
    end

    it 'returns :cautioned for score between -0.5 and -0.1' do
      expect(evaluator.verdict(-0.3)).to eq(:cautioned)
    end

    it 'returns :permitted for score above -0.1' do
      expect(evaluator.verdict(0.0)).to eq(:permitted)
    end

    it 'returns :permitted for positive scores' do
      expect(evaluator.verdict(0.5)).to eq(:permitted)
    end
  end

  describe '#detect_dilemma' do
    it 'returns nil when no conflict present' do
      scores = { care: 0.5, fairness: 0.4, loyalty: 0.3, authority: 0.2, sanctity: 0.3, liberty: 0.4 }
      expect(evaluator.detect_dilemma(scores)).to be_nil
    end

    it 'returns nil when all foundations agree negatively' do
      scores = { care: -0.8, fairness: -0.7, loyalty: -0.6, authority: -0.5, sanctity: -0.6, liberty: -0.5 }
      expect(evaluator.detect_dilemma(scores)).to be_nil
    end

    it 'returns a dilemma hash when care and fairness strongly disagree' do
      scores = { care: 0.9, fairness: -0.8, loyalty: 0.1, authority: 0.1, sanctity: 0.1, liberty: 0.1 }
      dilemma = evaluator.detect_dilemma(scores)
      expect(dilemma).not_to be_nil
      expect(dilemma).to include(:type, :approving, :opposing, :tension, :counter_tension, :detected_at)
    end

    it 'classifies care vs fairness conflict as :utilitarian' do
      scores = { care: 0.9, fairness: -0.8, loyalty: 0.0, authority: 0.0, sanctity: 0.0, liberty: 0.0 }
      dilemma = evaluator.detect_dilemma(scores)
      expect(dilemma[:type]).to eq(:utilitarian)
    end

    it 'classifies authority conflict as :deontological' do
      scores = { care: 0.0, fairness: 0.0, loyalty: 0.5, authority: -0.8, sanctity: 0.5, liberty: 0.0 }
      dilemma = evaluator.detect_dilemma(scores)
      expect(dilemma[:type]).to eq(:deontological)
    end

    it 'classifies loyalty vs sanctity conflict as :virtue_ethics' do
      scores = { care: 0.0, fairness: 0.0, loyalty: 0.8, authority: 0.0, sanctity: -0.7, liberty: 0.0 }
      dilemma = evaluator.detect_dilemma(scores)
      expect(dilemma[:type]).to eq(:virtue_ethics)
    end

    it 'lists approving and opposing foundations' do
      scores = { care: 0.9, fairness: -0.8, loyalty: 0.0, authority: 0.0, sanctity: 0.0, liberty: 0.0 }
      dilemma = evaluator.detect_dilemma(scores)
      expect(dilemma[:approving]).to include(:care)
      expect(dilemma[:opposing]).to include(:fairness)
    end
  end

  describe '#update_sensitivity' do
    it 'adjusts sensitivity for a known foundation' do
      original = evaluator.sensitivities[:care]
      evaluator.update_sensitivity(:care, 0.9)
      expect(evaluator.sensitivities[:care]).not_to eq(original)
    end

    it 'changes sensitivity by a small amount (slow EMA)' do
      original = evaluator.sensitivities[:care]
      evaluator.update_sensitivity(:care, 1.0)
      diff = (evaluator.sensitivities[:care] - original).abs
      expect(diff).to be <= Legion::Extensions::Conscience::Helpers::Constants::FOUNDATION_ALPHA + 0.001
    end

    it 'ignores unknown foundations without error' do
      expect { evaluator.update_sensitivity(:unknown_foundation, 0.5) }.not_to raise_error
    end

    it 'clamps outcome magnitude to [0.0, 1.0] when updating' do
      expect { evaluator.update_sensitivity(:care, 5.0) }.not_to raise_error
      expect(evaluator.sensitivities[:care]).to be_between(0.0, 1.0)
    end
  end

  describe 'foundation-specific evaluation' do
    it 'scores care positively when benefit_to_others is high' do
      result = evaluator.evaluate(action: :help, context: { benefit_to_others: 1.0, harm_to_others: 0.0 })
      expect(result[:scores][:care]).to be > 0.0
    end

    it 'scores care negatively when harm_to_others is high' do
      result = evaluator.evaluate(action: :harm, context: { harm_to_others: 1.0, benefit_to_others: 0.0 })
      expect(result[:scores][:care]).to be < 0.0
    end

    it 'penalizes care further when vulnerable_affected is true' do
      without_vuln = evaluator.evaluate(action: :act, context: { harm_to_others: 0.5, vulnerable_affected: false })
      with_vuln    = evaluator.evaluate(action: :act, context: { harm_to_others: 0.5, vulnerable_affected: true })
      expect(with_vuln[:scores][:care]).to be < without_vuln[:scores][:care]
    end

    it 'scores liberty positively when consent_present is true' do
      with_consent    = evaluator.evaluate(action: :act, context: { consent_present: true, autonomy_preservation: 0.5 })
      without_consent = evaluator.evaluate(action: :act, context: { consent_present: false, autonomy_preservation: 0.5 })
      expect(with_consent[:scores][:liberty]).to be > without_consent[:scores][:liberty]
    end
  end
end
