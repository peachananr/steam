module Locomotive::Steam
  module Adapters
    module MongoDB

      class Query

        attr_reader :criteria, :sort

        def initialize(scope, localized_attributes, &block)
          @criteria, @sort, @fields = {}, nil, nil
          @scope, @localized_attributes = scope, localized_attributes

          apply_default_scope

          instance_eval(&block) if block_given?
        end

        def where(criterion = nil)
          self.tap do
            @criteria.merge!(criterion) unless criterion.nil?
          end
        end

        def order_by(*args)
          self.tap do
            @sort = [*args]
          end
        end

        def only(*args)
          self.tap do
            @fields = [*args]
          end
        end

        def against(collection)
          _query = to_origin
          selector, fields, sort = _query.selector, _query.options[:fields], _query.options[:sort]

          collection.find(selector).tap do |results|
            results.sort(sort) if sort
            results.select(fields) if fields
          end
        end

        def to_origin
          build_origin_query.only(@fields).where(@criteria).order_by(*@sort)
        end

        private

        def build_origin_query
          ::Origin::Query.new(build_aliases(@localized_attributes, @scope.locale))
        end

        def build_aliases(localized_attributes, locale)
          localized_attributes.inject({}) do |aliases, name|
            aliases.tap do
              aliases[name.to_s] = "#{name}.#{locale}"
            end
          end
        end

        def apply_default_scope
          where(site_id: @scope.site._id) if @scope.site
        end

      end

    end
  end
end