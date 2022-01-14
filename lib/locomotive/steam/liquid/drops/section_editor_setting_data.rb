module Locomotive
  module Steam
    module Liquid
      module Drops

        # Required to allow the sync between the Locomotive editor
        # and the string/text inputs of a section and section block
        class SectionEditorSettingData < ::Liquid::Drop

          def initialize(section)
            @section = section
          end

          def liquid_method_missing(meth)
            block   = nil
            prefix  = "section-#{@context['section'].id}"
            matches = (@context['forloop.name'] || '').match(SECTIONS_BLOCK_FORLOOP_REGEXP)

            # are we inside a block?
            if matches && variable_name = matches[:name]
              block = @context[variable_name]
              prefix += "-block.#{block.id}"
            end

            # only string and text inputs can synced
            if is_text?(meth.to_s, block)
              %( data-locomotive-editor-setting="#{prefix}.#{meth}")
            else
              ''
            end
          end

          private

          def is_text?(id, block)
            settings = block ? block_settings(block['type']) : section_settings

            # can happen if the developer forgets to assign a type to
            # the default blocks
            return false if settings.blank?

            text_inputs(settings).include?(id)
          end          

          def text_inputs(settings)
            settings.map do |input|
              %w(text textarea).include?(input['type']) ? input['id'] : nil
            end.compact
          end

          def block_settings(type)
            @section.definition['blocks'].find do |block|
              block['type'] == type
            end&.fetch('settings', nil)
          end

          def section_settings
            @section.definition['settings']
          end
        end

      end
    end
  end
end
