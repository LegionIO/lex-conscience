# frozen_string_literal: true

require 'legion/extensions/conscience/helpers/constants'
require 'legion/extensions/conscience/helpers/moral_evaluator'
require 'legion/extensions/conscience/helpers/moral_store'
require 'legion/extensions/conscience/runners/conscience'

module Legion
  module Extensions
    module Conscience
      class Client
        include Runners::Conscience

        attr_reader :moral_store

        def initialize(moral_store: nil, **)
          @moral_store = moral_store || Helpers::MoralStore.new
        end
      end
    end
  end
end
