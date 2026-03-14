# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Conscience::Helpers::Constants do
  describe 'MORAL_FOUNDATIONS' do
    it 'defines 6 foundations' do
      expect(described_class::MORAL_FOUNDATIONS.size).to eq(6)
    end

    it 'has weights summing to 1.0' do
      total = described_class::MORAL_FOUNDATIONS.values.sum { |v| v[:weight] }
      expect(total).to be_within(0.001).of(1.0)
    end

    it 'includes all 6 Haidt foundations' do
      expect(described_class::MORAL_FOUNDATIONS.keys).to contain_exactly(
        :care, :fairness, :loyalty, :authority, :sanctity, :liberty
      )
    end

    it 'gives care the highest weight (0.25)' do
      expect(described_class::MORAL_FOUNDATIONS[:care][:weight]).to eq(0.25)
    end

    it 'gives fairness the second highest weight (0.20)' do
      expect(described_class::MORAL_FOUNDATIONS[:fairness][:weight]).to eq(0.20)
    end

    it 'gives liberty the lowest weight (0.10)' do
      expect(described_class::MORAL_FOUNDATIONS[:liberty][:weight]).to eq(0.10)
    end

    it 'is frozen' do
      expect(described_class::MORAL_FOUNDATIONS).to be_frozen
    end

    it 'each foundation has a description' do
      described_class::MORAL_FOUNDATIONS.each_value do |config|
        expect(config[:description]).to be_a(String)
        expect(config[:description]).not_to be_empty
      end
    end
  end

  describe 'MORAL_VERDICTS' do
    it 'defines 4 verdicts' do
      expect(described_class::MORAL_VERDICTS.size).to eq(4)
    end

    it 'includes permitted, cautioned, conflicted, prohibited' do
      expect(described_class::MORAL_VERDICTS).to include(:permitted, :cautioned, :conflicted, :prohibited)
    end

    it 'is frozen' do
      expect(described_class::MORAL_VERDICTS).to be_frozen
    end
  end

  describe 'FOUNDATION_ALPHA' do
    it 'is 0.05 (very slow adaptation)' do
      expect(described_class::FOUNDATION_ALPHA).to eq(0.05)
    end

    it 'is less than 0.1' do
      expect(described_class::FOUNDATION_ALPHA).to be < 0.1
    end
  end

  describe 'CONFLICT_THRESHOLD' do
    it 'is 0.3' do
      expect(described_class::CONFLICT_THRESHOLD).to eq(0.3)
    end
  end

  describe 'PROHIBITION_THRESHOLD' do
    it 'is -0.5' do
      expect(described_class::PROHIBITION_THRESHOLD).to eq(-0.5)
    end
  end

  describe 'CAUTION_THRESHOLD' do
    it 'is -0.1' do
      expect(described_class::CAUTION_THRESHOLD).to eq(-0.1)
    end

    it 'is greater than PROHIBITION_THRESHOLD' do
      expect(described_class::CAUTION_THRESHOLD).to be > described_class::PROHIBITION_THRESHOLD
    end
  end

  describe 'MAX_MORAL_HISTORY' do
    it 'caps at 100' do
      expect(described_class::MAX_MORAL_HISTORY).to eq(100)
    end
  end

  describe 'DILEMMA_TYPES' do
    it 'defines 3 dilemma types' do
      expect(described_class::DILEMMA_TYPES.size).to eq(3)
    end

    it 'includes utilitarian, deontological, virtue_ethics' do
      expect(described_class::DILEMMA_TYPES).to include(:utilitarian, :deontological, :virtue_ethics)
    end

    it 'is frozen' do
      expect(described_class::DILEMMA_TYPES).to be_frozen
    end
  end

  describe 'INITIAL_SENSITIVITY' do
    it 'is 1.0 (fully sensitive at boot, decays through experience)' do
      expect(described_class::INITIAL_SENSITIVITY).to eq(1.0)
    end
  end

  describe 'MORAL_SCORE_RANGE' do
    it 'spans -1.0 to 1.0' do
      expect(described_class::MORAL_SCORE_RANGE[:min]).to eq(-1.0)
      expect(described_class::MORAL_SCORE_RANGE[:max]).to eq(1.0)
    end
  end
end
