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
    let(:template_source) do
      <<~ERB
        <section class="apiary">
          <h1><%= @apiary.name %></h1>
          <% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>
            <p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>
          <% end %>
        </section>
      ERB
    end

    before do
      write_file(template, template_source)
    end

    it 'counts each reference' do
      expect(violation.count).to eq(2)
    end

    it 'shows context from the template rather than the extracted Ruby' do
      contexts = violation.sources_with_contexts.values.flatten

      expect(contexts.size).to eq(2)
      expect(contexts).to all(include('<% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>'))
    end

    it 'shows the lines around each reference' do
      expect(violation.sources_with_contexts(start_offset: 1, end_offset: 1).values.flatten).to eq(
        [
          <<~CONTEXT,
            > #{template}:3 (L2..4)

            <h1><%= @apiary.name %></h1>
            <% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>
              <p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>
          CONTEXT
          <<~CONTEXT
            > #{template}:4 (L3..5)

            <% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>
              <p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>
            <% end %>
          CONTEXT
        ]
      )
    end

    context 'when a reference is near the top of the template' do
      let(:template_source) do
        <<~ERB
          <p><%= HoneyProductionNectar.as_of_now.volume %></p>
          <p>Updated daily</p>
          <p>Volumes are in liters</p>
          <footer>Hive Dashboard</footer>
        ERB
      end

      it 'shows context from the top of the template' do
        expect(violation.sources_with_contexts.values.flatten).to eq(["> #{template}:1 (L1..4)\n\n#{template_source}"])
      end
    end
  end
end
