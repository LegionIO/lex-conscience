# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Conscience::Helpers::MoralStore do
  subject(:store) { described_class.new }

  let(:permitted_result) do
    {
      action:         :deploy_patch,
      scores:         { care: 0.5, fairness: 0.4, loyalty: 0.3, authority: 0.2, sanctity: 0.4, liberty: 0.3 },
      weighted_score: 0.38,
      verdict:        :permitted,
      dilemma:        nil,
      sensitivities:  { care: 1.0, fairness: 1.0, loyalty: 1.0, authority: 1.0, sanctity: 1.0, liberty: 1.0 },
      evaluated_at:   Time.now.utc
    }
  end

  let(:cautioned_result) do
    {
      action:         :access_logs,
      scores:         { care: -0.2, fairness: -0.1, loyalty: 0.1, authority: 0.2, sanctity: 0.0, liberty: -0.3 },
      weighted_score: -0.06,
      verdict:        :cautioned,
      dilemma:        nil,
      sensitivities:  { care: 1.0, fairness: 1.0, loyalty: 1.0, authority: 1.0, sanctity: 1.0, liberty: 1.0 },
      evaluated_at:   Time.now.utc
    }
  end

  let(:prohibited_result) do
    {
      action:         :delete_user_data,
      scores:         { care: -0.9, fairness: -0.8, loyalty: -0.5, authority: -0.4, sanctity: -0.7, liberty: -0.6 },
      weighted_score: -0.67,
      verdict:        :prohibited,
      dilemma:        nil,
      sensitivities:  { care: 1.0, fairness: 1.0, loyalty: 1.0, authority: 1.0, sanctity: 1.0, liberty: 1.0 },
      evaluated_at:   Time.now.utc
    }
  end

  let(:dilemma_result) do
    {
      action:         :trade_off_action,
      scores:         { care: 0.8, fairness: -0.7, loyalty: 0.1, authority: 0.0, sanctity: 0.0, liberty: 0.0 },
      weighted_score: 0.06,
      verdict:        :permitted,
      dilemma:        {
        type:            :utilitarian,
        approving:       [:care],
        opposing:        [:fairness],
        tension:         0.8,
        counter_tension: 0.7,
        detected_at:     Time.now.utc
      },
      sensitivities:  { care: 1.0, fairness: 1.0, loyalty: 1.0, authority: 1.0, sanctity: 1.0, liberty: 1.0 },
      evaluated_at:   Time.now.utc
    }
  end

  describe '#initialize' do
    it 'creates a default evaluator' do
      expect(store.evaluator).to be_a(Legion::Extensions::Conscience::Helpers::MoralEvaluator)
    end

    it 'accepts an injected evaluator' do
      custom_evaluator = Legion::Extensions::Conscience::Helpers::MoralEvaluator.new
      s = described_class.new(evaluator: custom_evaluator)
      expect(s.evaluator).to be(custom_evaluator)
    end

    it 'starts with empty history' do
      expect(store.history).to be_empty
    end

    it 'starts with empty dilemmas' do
      expect(store.dilemmas).to be_empty
    end
  end

  describe '#record_evaluation' do
    it 'adds to history' do
      store.record_evaluation(permitted_result)
      expect(store.history.size).to eq(1)
    end

    it 'returns the result unchanged' do
      result = store.record_evaluation(permitted_result)
      expect(result[:verdict]).to eq(:permitted)
    end

    it 'records dilemma when present' do
      store.record_evaluation(dilemma_result)
      expect(store.dilemmas.size).to eq(1)
    end

    it 'does not record dilemma when nil' do
      store.record_evaluation(permitted_result)
      expect(store.dilemmas).to be_empty
    end

    it 'caps history at MAX_MORAL_HISTORY' do
      (Legion::Extensions::Conscience::Helpers::Constants::MAX_MORAL_HISTORY + 10).times { store.record_evaluation(permitted_result) }
      expect(store.history.size).to eq(Legion::Extensions::Conscience::Helpers::Constants::MAX_MORAL_HISTORY)
    end
  end

  describe '#record_follow_through' do
    it 'increments followed_count on :followed outcome' do
      store.record_follow_through(:permitted, :followed)
      stats = store.aggregate_stats
      expect(stats[:followed_count]).to eq(1)
    end

    it 'increments overridden_count on :overridden outcome' do
      store.record_follow_through(:permitted, :overridden)
      stats = store.aggregate_stats
      expect(stats[:overridden_count]).to eq(1)
    end

    it 'calls update_sensitivity on the evaluator' do
      expect(store.evaluator).to receive(:update_sensitivity).at_least(:once)
      store.record_follow_through(:prohibited, :overridden)
    end
  end

  describe '#consistency_score' do
    it 'returns 1.0 with no history' do
      expect(store.consistency_score).to eq(1.0)
    end

    it 'returns 1.0 when all verdicts are followed' do
      3.times { store.record_follow_through(:permitted, :followed) }
      expect(store.consistency_score).to eq(1.0)
    end

    it 'returns 0.5 when half are followed and half overridden' do
      2.times { store.record_follow_through(:permitted, :followed) }
      2.times { store.record_follow_through(:prohibited, :overridden) }
      expect(store.consistency_score).to eq(0.5)
    end

    it 'returns a float between 0.0 and 1.0' do
      5.times { store.record_follow_through(:permitted, :followed) }
      3.times { store.record_follow_through(:cautioned, :overridden) }
      expect(store.consistency_score).to be_between(0.0, 1.0)
    end
  end

  describe '#foundation_sensitivities' do
    it 'returns sensitivities for all 6 foundations' do
      expect(store.foundation_sensitivities.keys).to contain_exactly(
        :care, :fairness, :loyalty, :authority, :sanctity, :liberty
      )
    end

    it 'returns rounded float values' do
      store.foundation_sensitivities.each_value do |s|
        expect(s).to be_a(Float)
      end
    end
  end

  describe '#recent_evaluations' do
    it 'returns empty array initially' do
      expect(store.recent_evaluations).to be_empty
    end

    it 'returns most recent evaluations up to limit' do
      5.times { store.record_evaluation(permitted_result) }
      store.record_evaluation(cautioned_result)
      recent = store.recent_evaluations(3)
      expect(recent.size).to eq(3)
    end

    it 'returns the most recent entries when over limit' do
      5.times { store.record_evaluation(permitted_result) }
      2.times { store.record_evaluation(prohibited_result) }
      recent = store.recent_evaluations(2)
      expect(recent.all? { |e| e[:verdict] == :prohibited }).to be true
    end
  end

  describe '#open_dilemmas' do
    it 'returns empty when no dilemmas exist' do
      store.record_evaluation(permitted_result)
      expect(store.open_dilemmas).to be_empty
    end

    it 'returns dilemmas when they exist' do
      store.record_evaluation(dilemma_result)
      expect(store.open_dilemmas.size).to eq(1)
    end
  end

  describe '#aggregate_stats' do
    it 'returns empty stats structure when no history' do
      stats = store.aggregate_stats
      expect(stats[:total_evaluations]).to eq(0)
      expect(stats[:consistency_score]).to eq(1.0)
    end

    it 'counts evaluations' do
      3.times { store.record_evaluation(permitted_result) }
      expect(store.aggregate_stats[:total_evaluations]).to eq(3)
    end

    it 'counts verdicts by type' do
      2.times { store.record_evaluation(permitted_result) }
      store.record_evaluation(cautioned_result)
      store.record_evaluation(prohibited_result)
      counts = store.aggregate_stats[:verdict_counts]
      expect(counts[:permitted]).to eq(2)
      expect(counts[:cautioned]).to eq(1)
      expect(counts[:prohibited]).to eq(1)
    end

    it 'includes dilemma count' do
      store.record_evaluation(dilemma_result)
      expect(store.aggregate_stats[:dilemma_count]).to eq(1)
    end

    it 'includes foundation_sensitivities' do
      stats = store.aggregate_stats
      expect(stats[:foundation_sensitivities]).to include(:care, :fairness)
    end
  end
end
