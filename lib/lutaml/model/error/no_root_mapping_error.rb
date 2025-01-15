module Lutaml
  module Model
    class NoRootMappingError < Error
      def to_s
        "`no_root` is only allowed for Group classes"
      end
    end
  end
end
