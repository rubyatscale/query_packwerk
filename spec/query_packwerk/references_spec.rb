# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::References do
  include_context 'listed references'

  describe '.all' do
    it 'has each reference that pks lists' do
      expect(described_class.all.map(&:location)).to eq(
        [
          'app/services/apiary_summary.rb:2',
          'packs/apiary_reports/app/services/apiary_report.rb:2',
          'packs/apiary_reports/app/services/apiary_report.rb:4',
          'packs/hive_dashboard/app/models/hive.rb:2',
          'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:4',
          'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:8',
          'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:12',
          'packs/hive_dashboard/app/views/apiaries/show.html.erb'
        ]
      )
    end

    it 'runs pks once' do
      2.times { described_class.all }

      expect(QueryPackwerk::Pks).to have_received(:list_references).once
    end

    it 'runs pks again after a reload' do
      described_class.all
      described_class.reload!
      described_class.all

      expect(QueryPackwerk::Pks).to have_received(:list_references).twice
    end

    it 'says when pks lists a pack that has no package.yml' do
      listed_references.first['referencing_pack_name'] = 'packs/gone'

      expect { described_class.all }.to raise_error(
        QueryPackwerk::Pks::Error,
        'pks lists references from or to packs/gone, which has no package.yml'
      )
    end

    it 'finds a pack that a symlink points to, which ParsePackwerk does not' do
      Dir.mktmpdir do |shared_pack|
        File.write(File.join(shared_pack, 'package.yml'), "enforce_dependencies: true\n")
        File.symlink(shared_pack, 'packs/wax_reports')
        listed_references.first['referencing_pack_name'] = 'packs/wax_reports'

        expect(ParsePackwerk.find('packs/wax_reports')).to be_nil
        expect(described_class.all.first.consuming_pack.name).to eq('packs/wax_reports')
      end
    end
  end

  describe '.where' do
    it 'finds the references that break no rule' do
      expect(described_class.where(allowed: true).map(&:location)).to eq(
        [
          'app/services/apiary_summary.rb:2',
          'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:12'
        ]
      )
    end

    it 'finds the references that break a rule' do
      expect(described_class.where(violation_types: 'dependency').map(&:location)).to eq(
        [
          'packs/apiary_reports/app/services/apiary_report.rb:2',
          'packs/apiary_reports/app/services/apiary_report.rb:4'
        ]
      )
    end

    it 'finds the references from a pack' do
      expect(described_class.where(consuming_pack: '.').map(&:constant_name)).to eq(['::Beekeeping::Nectars'])
    end

    it 'finds nothing when pks lists no references' do
      listed_references.clear

      expect(described_class.where(producing_pack: 'packs/honey_production')).to be_empty
    end
  end

  describe '#sources_with_locations' do
    it 'gets the sources of each constant, where pks finds them' do
      expect(described_class.all.sources_with_locations).to eq(
        {
          '::Beekeeping::Nectars' => [
            ['app/services/apiary_summary.rb:2', 'Beekeeping::Nectars.status_for(apiary_id: 1)'],
            ['packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:12', 'Nectars.status_for(apiary_id: 1)']
          ],
          '::HoneyProductionNectar' => [
            ['packs/apiary_reports/app/services/apiary_report.rb:2', 'HoneyProductionNectar.count'],
            ['packs/apiary_reports/app/services/apiary_report.rb:4', 'HoneyProductionNectar.model_name.human'],
            ['packs/hive_dashboard/app/models/hive.rb:2', 'has_many :honey_production_nectars, dependent: :destroy'],
            ['packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:4', '::HoneyProductionNectar.as_of_now.find_by(apiary_id: 1)'],
            ['packs/hive_dashboard/app/views/apiaries/show.html.erb:1', 'HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id)'],
            ['packs/hive_dashboard/app/views/apiaries/show.html.erb:2', 'HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume']
          ],
          '::Beekeeping::NectarSource' => [
            ['packs/hive_dashboard/app/services/beekeeping/apiary_status.rb:8', 'NectarSource.where(apiary_id: 1).pluck(:name)']
          ]
        }
      )
    end
  end

  describe '#anonymous_source_counts' do
    it "shows how a pack's constants are used where the rules allow it" do
      allowed = described_class.where(producing_pack: 'packs/honey_production', allowed: true)

      expect(allowed.anonymous_source_counts).to eq(
        '::Beekeeping::Nectars' => {
          'Beekeeping::Nectars.status_for(apiary_id: _)' => 1,
          'Nectars.status_for(apiary_id: _)' => 1
        }
      )
    end
  end

  describe '#consumers' do
    it 'counts the references from each pack' do
      expect(described_class.all.consumers).to eq('packs/hive_dashboard' => 5, 'packs/apiary_reports' => 2, '.' => 1)
    end
  end

  describe '#including_files' do
    it 'finds the references in files that match' do
      references = described_class.all.including_files('packs/apiary_reports/**')

      expect(references).to be_a(described_class)
      expect(references.map(&:location)).to eq(
        [
          'packs/apiary_reports/app/services/apiary_report.rb:2',
          'packs/apiary_reports/app/services/apiary_report.rb:4'
        ]
      )
    end
  end
end
