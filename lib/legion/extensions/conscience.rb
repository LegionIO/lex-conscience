# frozen_string_literal: true

require 'legion/extensions/conscience/version'
require 'legion/extensions/conscience/helpers/constants'
require 'legion/extensions/conscience/helpers/moral_evaluator'
require 'legion/extensions/conscience/helpers/moral_store'
require 'legion/extensions/conscience/runners/conscience'
require 'legion/extensions/conscience/client'

module Legion
  module Extensions
    module Conscience
      extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
    end
  end
end
