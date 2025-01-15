module Lutaml
  module Model
    class OutOfRangeChoiceError < Error
      def to_s
        "Attributes must be in specified range in a choice"
      end
    end
  end
end
