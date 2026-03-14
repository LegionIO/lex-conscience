# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Conscience::Client do
  describe '#initialize' do
    it 'creates a default moral store' do
      client = described_class.new
      expect(client.moral_store).to be_a(Legion::Extensions::Conscience::Helpers::MoralStore)
    end

    it 'accepts an injected moral store' do
      store = Legion::Extensions::Conscience::Helpers::MoralStore.new
      client = described_class.new(moral_store: store)
      expect(client.moral_store).to be(store)
    end

    it 'ignores unknown kwargs' do
      expect { described_class.new(unknown: true, other: 42) }.not_to raise_error
    end
  end

  describe 'runner integration' do
    let(:client) { described_class.new }

    it { expect(client).to respond_to(:moral_evaluate) }
    it { expect(client).to respond_to(:moral_status) }
    it { expect(client).to respond_to(:moral_history) }
    it { expect(client).to respond_to(:update_moral_outcome) }
    it { expect(client).to respond_to(:moral_dilemmas) }
    it { expect(client).to respond_to(:conscience_stats) }
  end

  describe 'shared state' do
    it 'accumulates evaluations across multiple calls' do
      client = described_class.new
      context = { benefit_to_others: 0.5, harm_to_others: 0.0, consent_present: true }
      7.times { client.moral_evaluate(action: :test, context: context) }
      expect(client.moral_history[:total]).to eq(7)
    end

    it 'uses the same moral store for evaluations and status' do
      client = described_class.new
      client.moral_evaluate(action: :test, context: { benefit_to_others: 0.5 })
      status = client.moral_status
      expect(status[:stats][:total_evaluations]).to eq(1)
    end
  end

  describe 'injected store passthrough' do
    it 'uses the injected store for evaluations' do
      store = Legion::Extensions::Conscience::Helpers::MoralStore.new
      client = described_class.new(moral_store: store)
      client.moral_evaluate(action: :test, context: {})
      expect(store.history.size).to eq(1)
    end
  end
end
