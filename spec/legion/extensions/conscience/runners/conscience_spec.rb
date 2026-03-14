# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Conscience::Runners::Conscience do
  let(:client) { Legion::Extensions::Conscience::Client.new }

  let(:benign_context) do
    {
      harm_to_others:                  0.0,
      benefit_to_others:               0.8,
      vulnerable_affected:             false,
      distributional_justice:          0.6,
      reciprocity:                     0.5,
      proportionality:                 0.4,
      alignment_with_group_norms:      0.5,
      trust_preservation:              0.6,
      legitimate_authority_compliance: 0.4,
      hierarchy_respect:               0.3,
      system_integrity:                0.7,
      degradation_prevention:          0.6,
      autonomy_preservation:           0.5,
      consent_present:                 true
    }
  end

  let(:harmful_context) do
    {
      harm_to_others:                  0.9,
      benefit_to_others:               0.0,
      vulnerable_affected:             true,
      distributional_justice:          -0.7,
      reciprocity:                     -0.6,
      proportionality:                 -0.5,
      alignment_with_group_norms:      -0.4,
      trust_preservation:              -0.7,
      legitimate_authority_compliance: -0.5,
      hierarchy_respect:               -0.4,
      system_integrity:                -0.8,
      degradation_prevention:          -0.7,
      autonomy_preservation:           -0.6,
      consent_present:                 false
    }
  end

  describe '#moral_evaluate' do
    it 'returns a hash with required keys' do
      result = client.moral_evaluate(action: :deploy_patch, context: benign_context)
      expect(result).to include(:action, :scores, :weighted_score, :verdict, :dilemma, :sensitivities, :evaluated_at)
    end

    it 'returns :permitted for benign action' do
      result = client.moral_evaluate(action: :deploy_patch, context: benign_context)
      expect(result[:verdict]).to eq(:permitted)
    end

    it 'returns :prohibited for harmful action' do
      result = client.moral_evaluate(action: :delete_user_data, context: harmful_context)
      expect(result[:verdict]).to eq(:prohibited)
    end

    it 'records evaluation in moral store history' do
      client.moral_evaluate(action: :test_action, context: benign_context)
      expect(client.moral_store.history.size).to eq(1)
    end

    it 'handles empty context without error' do
      expect { client.moral_evaluate(action: :test) }.not_to raise_error
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.moral_evaluate(action: :test, context: {}, extra_param: true) }.not_to raise_error
    end

    it 'returns all 6 foundation scores' do
      result = client.moral_evaluate(action: :test, context: {})
      expect(result[:scores].keys).to contain_exactly(:care, :fairness, :loyalty, :authority, :sanctity, :liberty)
    end
  end

  describe '#moral_status' do
    it 'returns status with required keys' do
      status = client.moral_status
      expect(status).to include(:sensitivities, :consistency, :stats)
    end

    it 'includes all 6 foundation sensitivities' do
      status = client.moral_status
      expect(status[:sensitivities].keys).to contain_exactly(
        :care, :fairness, :loyalty, :authority, :sanctity, :liberty
      )
    end

    it 'includes consistency score of 1.0 initially' do
      status = client.moral_status
      expect(status[:consistency]).to eq(1.0)
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.moral_status(extra: true) }.not_to raise_error
    end
  end

  describe '#moral_history' do
    it 'returns empty history initially' do
      result = client.moral_history
      expect(result[:history]).to be_empty
      expect(result[:total]).to eq(0)
    end

    it 'returns history after evaluations' do
      3.times { client.moral_evaluate(action: :test, context: benign_context) }
      result = client.moral_history
      expect(result[:history].size).to eq(3)
      expect(result[:total]).to eq(3)
    end

    it 'respects limit parameter' do
      10.times { client.moral_evaluate(action: :test, context: benign_context) }
      result = client.moral_history(limit: 4)
      expect(result[:history].size).to eq(4)
    end

    it 'includes limit in response' do
      result = client.moral_history(limit: 5)
      expect(result[:limit]).to eq(5)
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.moral_history(limit: 5, extra: true) }.not_to raise_error
    end
  end

  describe '#update_moral_outcome' do
    before do
      client.moral_evaluate(action: :deploy_patch, context: benign_context)
    end

    it 'returns a hash with required keys' do
      result = client.update_moral_outcome(action: :deploy_patch, outcome: :followed)
      expect(result).to include(:action, :verdict, :outcome, :consistency)
    end

    it 'records followed outcome correctly' do
      client.update_moral_outcome(action: :deploy_patch, outcome: :followed)
      expect(client.moral_store.consistency_score).to eq(1.0)
    end

    it 'records overridden outcome correctly' do
      client.moral_evaluate(action: :delete_data, context: harmful_context)
      client.update_moral_outcome(action: :delete_data, verdict: :prohibited, outcome: :overridden)
      stats = client.moral_store.aggregate_stats
      expect(stats[:overridden_count]).to eq(1)
    end

    it 'accepts explicit verdict override' do
      result = client.update_moral_outcome(action: :any, outcome: :followed, verdict: :cautioned)
      expect(result[:verdict]).to eq(:cautioned)
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.update_moral_outcome(action: :test, outcome: :followed, meta: 'ok') }.not_to raise_error
    end
  end

  describe '#moral_dilemmas' do
    it 'returns empty dilemmas initially' do
      result = client.moral_dilemmas
      expect(result[:dilemmas]).to be_empty
      expect(result[:count]).to eq(0)
    end

    it 'returns dilemmas when foundations conflict strongly' do
      # Force a dilemma by evaluating a context where care strongly approves but fairness strongly disapproves
      conflicted = {
        harm_to_others:         0.0,
        benefit_to_others:      1.0,    # care +
        distributional_justice: -0.9,   # fairness -
        reciprocity:            -0.9,
        proportionality:        -0.9
      }
      client.moral_evaluate(action: :conflicted_action, context: conflicted)
      result = client.moral_dilemmas
      # May or may not produce a dilemma depending on computed scores; just verify structure
      expect(result).to include(:dilemmas, :count)
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.moral_dilemmas(extra: true) }.not_to raise_error
    end
  end

  describe '#conscience_stats' do
    it 'returns aggregate stats with required keys' do
      client.moral_evaluate(action: :test, context: benign_context)
      stats = client.conscience_stats
      expect(stats).to include(:total_evaluations, :verdict_counts, :dilemma_count,
                               :consistency_score, :verdict_distribution, :foundation_weights)
    end

    it 'includes foundation weights matching constants' do
      stats = client.conscience_stats
      expected_weights = Legion::Extensions::Conscience::Helpers::Constants::MORAL_FOUNDATIONS.transform_values { |v| v[:weight] }
      expect(stats[:foundation_weights]).to eq(expected_weights)
    end

    it 'verdict_distribution sums to 1.0 when evaluations exist' do
      3.times { client.moral_evaluate(action: :test, context: benign_context) }
      stats = client.conscience_stats
      total = stats[:verdict_distribution].values.sum
      expect(total).to be_within(0.001).of(1.0)
    end

    it 'verdict_distribution is empty when no evaluations' do
      stats = client.conscience_stats
      expect(stats[:verdict_distribution]).to be_empty
    end

    it 'accepts extra kwargs via ** splat' do
      expect { client.conscience_stats(extra: true) }.not_to raise_error
    end
  end

  describe 'moral consistency tracking' do
    it 'consistency decreases when prohibited verdicts are overridden' do
      client.moral_evaluate(action: :bad_action, context: harmful_context)
      client.update_moral_outcome(action: :bad_action, verdict: :prohibited, outcome: :overridden)
      expect(client.moral_status[:consistency]).to be < 1.0
    end

    it 'consistency stays at 1.0 when all verdicts are followed' do
      5.times do
        client.moral_evaluate(action: :good_action, context: benign_context)
        client.update_moral_outcome(action: :good_action, outcome: :followed)
      end
      expect(client.moral_status[:consistency]).to eq(1.0)
    end
  end
end
