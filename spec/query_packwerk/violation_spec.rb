# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::Violation do
  include_context 'pseudo packs'

  context 'when the violating file is an ERB template' do
    subject(:violation) do
      described_class.new(
        original_violation: ParsePackwerk::Violation.new(
          type: 'privacy',
          to_package_name: package_name,
          class_name: '::HoneyProductionNectar',
          files: [template]
        ),
        consuming_pack: ParsePackwerk.find(package_name)
      )
    end

    let(:template) { 'packs/hive_dashboard/app/views/apiaries/show.html.erb' }

    before do
      write_file(template, <<~ERB)
        <section class="apiary">
          <h1><%= @apiary.name %></h1>
          <% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>
            <p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>
          <% end %>
        </section>
      ERB
    end

    it 'counts each reference' do
      expect(violation.count).to eq(2)
    end

    it 'shows context from the template rather than the extracted Ruby' do
      template_line = a_string_including('<% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>')

      expect(violation.sources_with_contexts.values.flatten).to match([template_line, template_line])
    end
  end
end
