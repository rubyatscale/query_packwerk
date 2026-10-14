# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::Reference do
  include_context 'listed references'

  define_method(:reference_at) do |location|
    QueryPackwerk::References.all.find { |reference| reference.location == location }
  end

  describe 'a reference that pks lists' do
    subject(:reference) { reference_at('packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:4') }

    it 'says where it is and which packs it is between' do
      expect(reference).to have_attributes(
        constant_name: '::HoneyProductionNectar',
        class_name: '::HoneyProductionNectar',
        file: 'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb',
        files: ['packs/hive_dashboard/app/services/beekeeping/apiary_status.rb'],
        line: 4,
        column: 6
      )
      expect(reference.consuming_pack.name).to eq('packs/hive_dashboard')
      expect(reference.producing_pack.name).to eq('packs/honey_production')
    end

    it 'says which rules it breaks' do
      expect(reference.violations).to contain_exactly(
        an_instance_of(described_class::Violation).and(have_attributes(type: 'privacy', strict: false, recorded: true))
      )
      expect(reference.violation_types).to eq(['privacy'])
      expect(reference).not_to be_allowed
    end

    it 'finds its source where pks says it is' do
      expect(reference.sources_with_locations).to eq(
        [['packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:4', '::HoneyProductionNectar.as_of_now.find_by(apiary_id: 1)']]
      )
      expect(reference.anonymous_sources).to eq(['HoneyProductionNectar.as_of_now.find_by(apiary_id: _)'])
      expect(reference.count).to eq(1)
    end

    it 'can be queried' do
      expect(reference.deconstruct_keys(nil)).to include(
        constant_name: '::HoneyProductionNectar',
        pack_name: 'packs/honey_production',
        file: 'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb',
        allowed: false,
        violation_types: ['privacy'],
        privacy: true,
        dependency: false,
        consuming_pack: 'packs/hive_dashboard',
        producing_pack: 'packs/honey_production',
        producing_owner: 'Honey',
        consuming_owner: 'Unowned',
        owner: 'Honey',
        owned: true
      )
    end

    it 'can be inspected' do
      expect(reference.inspect).to eq(
        '#<QueryPackwerk::Reference packs/hive_dashboard -> ::HoneyProductionNectar (privacy) ' \
        'at packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:4>'
      )
    end
  end

  describe 'a reference in a file that names its constant elsewhere too' do
    subject(:reference) { reference_at('packs/apiary_reports/app/services/apiary_report.rb:2') }

    it 'has only the source where pks says it is' do
      expect(reference.count).to eq(1)
      expect(reference.source_counts).to eq('HoneyProductionNectar.count' => 1)
      expect(reference.anonymous_sources_with_locations).to eq(
        'HoneyProductionNectar.count' => ['packs/apiary_reports/app/services/apiary_report.rb:2']
      )
      expect(reference.sources_with_contexts(start_offset: 0, end_offset: 0)).to eq(
        'HoneyProductionNectar.count' => [
          "> packs/apiary_reports/app/services/apiary_report.rb:2 (L2..2)\n\ndef nectar_count = HoneyProductionNectar.count\n"
        ]
      )
    end

    it 'says which rules it breaks, and which of them a package_todo.yml records' do
      expect(reference.violations.map { |violation| [violation.type, violation.recorded] }).to eq(
        [['dependency', true], ['privacy', false]]
      )
      expect(reference.deconstruct_keys(%i[violation_types dependency privacy])).to eq(
        violation_types: %w[dependency privacy], dependency: true, privacy: true
      )
    end
  end

  it 'says whether the pack that enforces a rule is strict about it' do
    listed_references.first['violations'] = [{ 'violation_type' => 'privacy', 'strict' => true, 'recorded' => false }]

    expect(reference_at('app/services/apiary_summary.rb:2').violations.map(&:strict)).to eq([true])
  end

  context 'when the app is loaded with Rails' do
    before do
      stub_const('Rails', Module.new)
      application_record = stub_const('ApplicationRecord', Class.new)
      stub_const('HoneyProductionNectar', Class.new(application_record))
      stub_const('ApiaryReportCard', Class.new)
    end

    it 'says whether its constant is an Active Record model' do
      expect(
        [
          'packs/apiary_reports/app/services/apiary_report.rb:2',
          'packs/hive_dashboard/app/services/report_link.rb:2',
          'app/services/apiary_summary.rb:2'
        ].map { |location| reference_at(location).deconstruct_keys([:is_active_record]).fetch(:is_active_record) }
      ).to eq([true, false, false])
    end

    it 'looks its constant up only for a query that asks about it' do
      allow(Kernel).to receive(:const_defined?).and_call_original

      expect(QueryPackwerk::References.where(allowed: true).count).to eq(2)
      # Once, as where checks the query's keys against the first reference's
      expect(Kernel).to have_received(:const_defined?).once
    end
  end

  it 'is allowed when it breaks no rule' do
    reference = reference_at('packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:12')

    expect(reference).to be_allowed
    expect(reference.inspect).to eq(
      '#<QueryPackwerk::Reference packs/hive_dashboard -> ::Beekeeping::Nectars (allowed) ' \
      'at packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:12>'
    )
  end

  it 'finds a constant that the code names relatively' do
    reference = reference_at('packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:8')

    expect(reference.constant_name).to eq('::Beekeeping::NectarSource')
    expect(reference.sources.map(&:source)).to eq(['NectarSource.where(apiary_id: 1).pluck(:name)'])
  end

  it 'finds a constant after multibyte characters on its line, where pks counts bytes' do
    reference = reference_at('packs/apiary_reports/app/services/apiary_report.rb:4')

    expect(reference.column).to eq(31)
    expect(reference.sources.map(&:source)).to eq(['HoneyProductionNectar.model_name.human'])
  end

  it 'finds the association that pks infers a reference from' do
    reference = reference_at('packs/hive_dashboard/app/models/hive.rb:2')

    expect(reference.sources.map(&:source)).to eq(['has_many :honey_production_nectars, dependent: :destroy'])
    expect(reference.anonymous_sources).to eq(['has_many _, dependent: _'])
  end

  it 'finds nothing when the code at its position has changed since pks ran' do
    write_file('packs/hive_dashboard/app/models/hive.rb', "class Hive < ApplicationRecord\nend\n")

    reference = reference_at('packs/hive_dashboard/app/models/hive.rb:2')

    expect(reference.sources).to eq([])
    expect(reference.count).to eq(0)
  end

  context 'when the reference is in an ERB template' do
    subject(:reference) { reference_at('packs/hive_dashboard/app/views/apiaries/show.html.erb') }

    it 'has no position' do
      expect(reference).to have_attributes(line: nil, column: nil, location: 'packs/hive_dashboard/app/views/apiaries/show.html.erb')
    end

    it 'finds every place the template names the constant, which pks lists once' do
      expect(reference.sources_with_locations).to eq(
        [
          ['packs/hive_dashboard/app/views/apiaries/show.html.erb:1', 'HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id)'],
          ['packs/hive_dashboard/app/views/apiaries/show.html.erb:2', 'HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume']
        ]
      )
      expect(reference.count).to eq(2)
    end

    it 'shows context from the template' do
      expect(reference.sources_with_contexts(start_offset: 0, end_offset: 0)).to eq(
        'HoneyProductionNectar.as_of_now.exists?(apiary_id: _)' => [
          "> packs/hive_dashboard/app/views/apiaries/show.html.erb:1 (L1..1)\n\n" \
          "<% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>\n"
        ],
        'HoneyProductionNectar.as_of_now.find_by(apiary_id: _).volume' => [
          "> packs/hive_dashboard/app/views/apiaries/show.html.erb:2 (L2..2)\n\n" \
          "<p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>\n"
        ]
      )
    end
  end
end
