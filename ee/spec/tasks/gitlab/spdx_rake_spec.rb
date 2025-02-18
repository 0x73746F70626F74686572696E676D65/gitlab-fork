# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:rake tasks', :silence_stdout, feature_category: :software_composition_analysis do
  before do
    Rake.application.rake_require 'tasks/gitlab/spdx'
  end

  describe 'import' do
    subject { run_rake_task 'gitlab:spdx:import' }

    let(:path) { Gitlab::SPDX::CatalogueGateway::OFFLINE_CATALOGUE_PATH }
    let(:data) { { license1: 'test', license2: 'test2' } }

    context 'with successful download of the catalogue' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 200,
          body: data.to_json)
        allow(IO).to receive(:write)
        expect(IO).to receive(:write).with(path, anything, mode: 'w')
      end

      it 'saves the catalogue to the file' do
        expect { subject }.to output("Local copy of SPDX catalogue is saved to #{path}\n").to_stdout
      end
    end

    context 'when downloaded catalogue is broken' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 200,
          body: data.inspect)
      end

      it 'raises parsing failure' do
        expect { subject }.to output(/Import of SPDX catalogue failed: unexpected colon \(after \)/).to_stdout
      end
    end

    context 'with network failure' do
      before do
        stub_request(:get, Gitlab::SPDX::CatalogueGateway::ONLINE_CATALOGUE_URL).to_return(status: 404)
      end

      it 'raises network failure error' do
        expect { subject }.to output("Import of SPDX catalogue failed: Network failure\n").to_stdout
      end
    end
  end
end
