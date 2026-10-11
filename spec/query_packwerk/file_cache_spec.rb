# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::FileCache do
  subject(:file_cache) { described_class.new }

  def sources_in(file_name)
    file_cache
      .get_full_sources(file_name: file_name, class_name: '::Billing::Invoice')
      .map { |node| [node.loc.line, node.source] }
  end

  describe '#get_full_sources' do
    it 'finds references in the Ruby code of an ERB template, on their template lines' do
      write_file('app/views/invoices/show.html.erb', <<~ERB)
        <div class="invoice">
          <%# Billing::Invoice in a comment is not a reference %> <%= Billing::Invoice.count %>
          <p>Escaped: <%%= Billing::Invoice %></p>
          <% if Billing::Invoice.overdue?(@account) %>
            <p><%= Billing::Invoice.for(@account).total %></p>
          <% end %>
          <%= form_with model: @account do |form| %>
            <%= form.text_field :name %> <%= Billing::Invoice.statuses.first %>
          <% end %>
        </div>
      ERB

      expect(sources_in('app/views/invoices/show.html.erb')).to eq(
        [
          [2, 'Billing::Invoice.count'],
          [4, 'Billing::Invoice.overdue?(@account)'],
          [5, 'Billing::Invoice.for(@account).total'],
          [8, 'Billing::Invoice.statuses.first']
        ]
      )
    end

    it 'finds nothing in an ERB template without Ruby code' do
      write_file('app/views/pages/about.html.erb', "<p>About</p>\n")

      sources = nil
      expect { sources = sources_in('app/views/pages/about.html.erb') }.not_to output.to_stderr
      expect(sources).to eq([])
    end

    it 'finds nothing in a Ruby file with only comments' do
      write_file('app/models/invoice.rb', "# frozen_string_literal: true\n")

      sources = nil
      expect { sources = sources_in('app/models/invoice.rb') }.not_to output.to_stderr
      expect(sources).to eq([])
    end

    it 'warns that it found nothing in a file it could not parse' do
      write_file('app/models/invoice.rb', "Billing::Invoice.find(\n")

      sources = nil
      expect { sources = sources_in('app/models/invoice.rb') }
        .to output("Could not parse app/models/invoice.rb, so its violations are not included\n").to_stderr
      expect(sources).to eq([])
    end

    %w[app/views/invoices/show.xml.builder billing.gemspec config.ru Gemfile Rakefile].each do |file_name|
      it "finds references in #{file_name}" do
        write_file(file_name, "Billing::Invoice.find(1)\n")

        expect(sources_in(file_name)).to eq([[1, 'Billing::Invoice.find(1)']])
      end
    end
  end
end
