# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Elastic::Helper, :request_store, feature_category: :global_search do
  subject(:helper) { described_class.default }

  shared_context 'with a legacy index' do
    before do
      @index_name = helper.create_empty_index(with_alias: false, options: { index_name: helper.target_name }).each_key.first
    end
  end

  shared_context 'with an existing index and alias' do
    before do
      @index_name = helper.create_empty_index(with_alias: true).each_key.first
    end
  end

  after do
    helper.delete_index(index_name: @index_name) if @index_name
  end

  describe '.new' do
    it 'has the proper default values' do
      expect(helper).to have_attributes(
        version: ::Elastic::MultiVersionUtil::TARGET_VERSION,
        target_name: ::Elastic::Latest::Config.index_name)
    end

    context 'with a custom `index_name`' do
      let(:index_name) { 'custom-index-name' }

      subject(:helper) { described_class.new(target_name: index_name) }

      it 'has the proper `index_name`' do
        expect(helper).to have_attributes(target_name: index_name)
      end
    end
  end

  describe '.default' do
    it 'does not cache the value' do
      expect(described_class.default.object_id).not_to eq(described_class.default.object_id)
    end
  end

  describe '.connection_settings' do
    it 'returns a hash compatible with elasticsearcht-transport client settings' do
      settings = described_class.connection_settings(uri: "http://localhost:9200")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        path: "",
        port: 9200
      })
    end

    it 'works when given a URI' do
      settings = described_class.connection_settings(uri: Addressable::URI.parse("http://localhost:9200"))

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        path: "",
        port: 9200
      })
    end

    it 'parses credentials out of the uri' do
      settings = described_class.connection_settings(uri: "http://elastic:myp%40ssword@localhost:9200")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "elastic",
        password: "myp@ssword",
        path: "",
        port: 9200
      })
    end

    it 'prioritizes creds in arguments over those in url' do
      settings = described_class.connection_settings(uri: "http://elastic:password@localhost:9200", user: "myuser", password: "p@ssword")

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "p@ssword",
        path: "",
        port: 9200
      })
    end

    it 'sets password to empty string when only username is provided' do
      settings = described_class.connection_settings(uri: "http://localhost:9200", user: "myuser", password: nil)

      expect(settings).to eq({
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "",
        path: "",
        port: 9200
      })
    end
  end

  describe '.`url_string`' do
    it 'returns a percent encoded url string' do
      settings = {
        scheme: "http",
        host: "localhost",
        user: "myuser",
        password: "p@ssword",
        path: "/foo",
        port: 9200
      }

      expect(described_class.url_string(settings)).to eq("http://myuser:p%40ssword@localhost:9200/foo")
    end
  end

  describe '#default_mappings' do
    it 'returns only mappings of the main index' do
      expected = Elastic::Latest::Config.mappings.to_hash[:properties].keys

      expect(helper.default_mappings[:properties].keys).to match_array(expected)
    end

    context 'custom analyzers' do
      let(:custom_analyzers_mappings) do
        { properties: { title: { fields: { custom: true } } } }
      end

      before do
        allow(::Elastic::Latest::CustomLanguageAnalyzers).to receive(:custom_analyzers_mappings).and_return(custom_analyzers_mappings)
      end

      it 'merges custom language analyzers mappings' do
        expect(helper.default_mappings[:properties][:title]).to include(custom_analyzers_mappings[:properties][:title])
      end
    end
  end

  describe '#index_name_with_timestamp', time_travel_to: '2022-01-02 10:30:45 -0700' do
    subject { helper.index_name_with_timestamp('gitlab-production') }

    it 'returns correct index name' do
      is_expected.to eq('gitlab-production-20220102-1730')
    end

    it 'supports name_suffix' do
      expect(helper.index_name_with_timestamp('gitlab-production', suffix: '-reindex')).to eq(
        'gitlab-production-20220102-1730-reindex'
      )
    end
  end

  describe '#create_migrations_index' do
    after do
      helper.delete_migrations_index
    end

    it 'creates the index' do
      expect { helper.create_migrations_index }
        .to change { helper.migrations_index_exists? }
              .from(false).to(true)
    end
  end

  describe '#create_standalone_indices', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/297357' do
    after do
      @indices.each do |index_name, _|
        helper.delete_index(index_name: index_name)
      end
    end

    it 'creates standalone indices' do
      @indices = helper.create_standalone_indices

      @indices.each do |index|
        expect(helper.index_exists?(index_name: index)).to be_truthy
      end
    end

    it 'raises an exception when there is an existing alias' do
      @indices = helper.create_standalone_indices

      expect { helper.create_standalone_indices }.to raise_error(/already exists/)
    end

    it 'does not raise an exception with skip_if_exists option' do
      @indices = helper.create_standalone_indices

      expect { helper.create_standalone_indices(options: { skip_if_exists: true }) }.not_to raise_error
    end

    it 'raises an exception when there is an existing index' do
      @indices = helper.create_standalone_indices(with_alias: false)

      expect { helper.create_standalone_indices(with_alias: false) }.to raise_error(/already exists/)
    end
  end

  describe '#delete_standalone_indices', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/297357' do
    before do
      helper.create_standalone_indices
    end

    subject { helper.delete_standalone_indices }

    it_behaves_like 'deletes all standalone indices'
  end

  describe '#delete_migrations_index' do
    before do
      helper.create_migrations_index
    end

    it 'deletes the migrations index' do
      expect { helper.delete_migrations_index }
        .to change { helper.migrations_index_exists? }
              .from(true).to(false)
    end
  end

  describe '#create_empty_index' do
    context 'with an empty cluster' do
      context 'with alias and index' do
        include_context 'with an existing index and alias'

        it 'creates index and alias' do
          expect(helper.index_exists?).to eq(true)
          expect(helper.alias_exists?).to eq(true)
        end
      end

      context 'when there is a legacy index' do
        include_context 'with a legacy index'

        it 'creates the index only' do
          expect(helper.index_exists?).to eq(true)
          expect(helper.alias_exists?).to eq(false)
        end
      end

      it 'creates an index with a custom name' do
        @index_name = 'test-custom-index-name'

        helper.create_empty_index(with_alias: false, options: { index_name: @index_name })

        expect(helper.index_exists?(index_name: @index_name)).to eq(true)
        expect(helper.index_exists?).to eq(false)
      end

      context 'with non-default number of shards' do
        let(:number_of_shards) { 7 }

        before do
          Elastic::IndexSetting.default.update!(number_of_shards: number_of_shards)
        end

        it 'creates an index with correct number of shards' do
          @index_name = helper.create_empty_index(with_alias: false).each_key.first

          settings = helper.get_settings(index_name: @index_name)
          expect(settings['number_of_shards'].to_i).to eq(number_of_shards)
        end
      end
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it 'raises an error' do
        expect { helper.create_empty_index }.to raise_error(/Index under '.+' already exists/)
      end

      it 'does not raise error with skip_if_exists option' do
        expect { helper.create_empty_index(options: { skip_if_exists: true }) }.not_to raise_error
      end
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it 'raises an error' do
        expect { helper.create_empty_index }.to raise_error(/Index or alias under '.+' already exists/)
      end
    end
  end

  describe '#delete_index' do
    subject { helper.delete_index }

    context 'without an existing index' do
      it 'fails gracefully' do
        is_expected.to be_falsy
      end
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end
  end

  describe '#index_exists?' do
    subject { helper.index_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_truthy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#migrations_index_exists?' do
    subject { helper.migrations_index_exists? }

    context 'without an existing migrations index' do
      before do
        helper.delete_migrations_index
      end

      it { is_expected.to be_falsy }
    end

    context 'when it exists' do
      before do
        helper.create_migrations_index
      end

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_exists?' do
    subject { helper.alias_exists? }

    context 'without an existing index' do
      it { is_expected.to be_falsy }
    end

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to be_falsy }
    end

    context 'when there is an alias' do
      include_context 'with an existing index and alias'

      it { is_expected.to be_truthy }
    end
  end

  describe '#alias_missing?' do
    it 'is the opposite of #alias_exists?' do
      expect(helper.alias_missing?).to eq(!helper.alias_exists?)
    end
  end

  describe '#cluster_free_size_bytes' do
    it 'returns valid cluster size' do
      expect(helper.cluster_free_size_bytes).to be_positive
    end
  end

  describe '#switch_alias' do
    include_context 'with an existing index and alias'

    let(:new_index_name) { 'test-switch-alias' }

    it 'switches the alias' do
      helper.create_empty_index(with_alias: false, options: { index_name: new_index_name })

      expect { helper.switch_alias(to: new_index_name) }
        .to change { helper.target_index_name }.to(new_index_name)

      helper.delete_index(index_name: new_index_name)
    end
  end

  describe '#index_size' do
    subject { helper.index_size }

    context 'when there is a legacy index' do
      include_context 'with a legacy index'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }
    end

    context 'when there is an alias', :aggregate_failures do
      include_context 'with an existing index and alias'

      it { is_expected.to have_key("docs") }
      it { is_expected.to have_key("store") }

      it 'supports providing the alias name' do
        alias_name = helper.target_name

        expect(helper.index_size(index_name: alias_name)).to have_key("docs")
        expect(helper.index_size(index_name: alias_name)).to have_key("store")
      end
    end
  end

  describe '#documents_count' do
    context 'when refresh is unset' do
      subject { helper.documents_count }

      context 'when there is a legacy index' do
        include_context 'with a legacy index'

        it { is_expected.to eq(0) }
      end

      context 'when there is an alias' do
        include_context 'with an existing index and alias'

        it { is_expected.to eq(0) }

        it 'supports providing the alias name' do
          alias_name = helper.target_name

          expect(helper.documents_count(index_name: alias_name)).to eq(0)
        end
      end
    end

    context 'when refresh is set' do
      subject(:count) { helper.documents_count(refresh: true) }

      it 'refreshes the index' do
        expect(helper).to receive(:refresh_index)

        count
      end
    end
  end

  describe '#delete_migration_record', :elastic do
    let(:migration) { ::Elastic::DataMigrationService.migrations.last }

    subject { helper.delete_migration_record(migration) }

    context 'when record exists' do
      it { is_expected.to be_truthy }
    end

    context 'when record does not exist' do
      before do
        allow(migration).to receive(:version).and_return(1)
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#standalone_indices_proxies' do
    subject(:standalone_indices_proxies) { helper.standalone_indices_proxies(target_classes: target_classes, exclude_classes: exclude_classes) }

    let(:target_classes) { nil }
    let(:exclude_classes) { nil }

    context 'when target_classes and exclude_classes are not provided' do
      it 'creates proxies for each separate class' do
        expect(subject.count).to eq(Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES.count)
      end
    end

    context 'when exclude_classes is provided' do
      let(:exclude_classes) { [Epic, Wiki] }

      it 'creates proxies for each separate classes except exclude_classes' do
        expect(subject.map(&:target)).to match_array(Gitlab::Elastic::Helper::ES_SEPARATE_CLASSES - exclude_classes)
      end
    end

    context 'when target_classes is provided' do
      let(:target_classes) { [Issue] }

      it 'creates proxies for only the target classes' do
        expect(subject.count).to eq(1)
      end
    end

    context 'with foreign keys mappings', :aggregate_failures do
      let(:ignore_columns) do
        {
          id: [Project, Issue, MergeRequest, Commit, Epic, User, WorkItem],
          project_id: :all,
          root_namespace_id: :all,
          target_project_id: :all,
          source_project_id: :all,
          author_id: :all,
          namespace_id: :all,
          assignee_id: :all,
          hashed_root_namespace_id: :all,
          work_item_type_id: :all,
          noteable_id: :all,
          owner_id: :all
        }
      end

      it 'has correct foreign key types' do
        standalone_indices_proxies.each do |proxy|
          mappings = proxy.mappings.to_hash

          mappings[:properties].select { |k, _| k =~ /(^id$)|(_id$)/ }.each do |key, value|
            next if ignore_columns[key] == :all || ignore_columns[key]&.include?(proxy.target)

            expect(value[:type]).to eq(:long), "#{proxy.target}.#{key} is not a long"
          end
        end
      end
    end
  end

  describe '#ping?' do
    subject { helper.ping? }

    it 'does not raise any exception' do
      allow(described_class.default.client).to receive(:ping).and_raise(StandardError)

      expect(subject).to be_falsey
      expect { subject }.not_to raise_exception
    end
  end

  describe '#get_meta', :elastic do
    subject { helper.get_meta }

    it 'returns version in meta field' do
      is_expected.to include('created_by' => Gitlab::VERSION)
    end
  end

  describe '#server_info' do
    subject { helper.server_info }

    context 'server is accessible' do
      before do
        allow(described_class.default.client).to receive(:info).and_return(info)
      end

      context 'using elasticsearch' do
        let(:info) do
          {
            'version' => {
              'number' => '7.9.3',
              'build_type' => 'docker',
              'lucene_version' => '8.11.4'
            }
          }
        end

        it 'returns server info' do
          is_expected.to include(distribution: 'elasticsearch', version: '7.9.3', build_type: 'docker', lucene_version: '8.11.4')
        end
      end

      context 'using opensearch' do
        let(:info) do
          {
            'version' => {
              'distribution' => 'opensearch',
              'number' => '1.0.0',
              'build_type' => 'tar',
              'lucene_version' => '8.10.1'
            }
          }
        end

        it 'returns server info' do
          is_expected.to include(distribution: 'opensearch', version: '1.0.0', build_type: 'tar', lucene_version: '8.10.1')
        end
      end
    end

    context 'server is inaccessible' do
      before do
        allow(described_class.default.client).to receive(:info).and_raise(StandardError)
      end

      it 'returns empty hash' do
        is_expected.to eq({})
      end
    end
  end

  describe '#get_mapping' do
    let(:index_name) { Issue.__elasticsearch__.index_name }

    subject { helper.get_mapping(index_name: index_name) }

    it 'reads mappings from client', :elastic do
      is_expected.not_to be_nil
    end
  end

  describe '#supported_version?' do
    subject { helper.supported_version? }

    context 'when Elasticsearch is not enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: false)
      end

      it { is_expected.to be_truthy }
    end

    context 'when Elasticsearch is enabled' do
      before do
        stub_ee_application_setting(elasticsearch_indexing: true)
        allow(described_class.default.client).to receive(:ping).and_return(true)
      end

      context 'when version is compatible' do
        before do
          allow_next_instance_of(::SystemCheck::App::SearchCheck) do |instance|
            allow(instance).to receive(:check?).and_return(true)
          end
        end

        it { is_expected.to be_truthy }
      end

      context 'when version is incompatible' do
        before do
          allow_next_instance_of(::SystemCheck::App::SearchCheck) do |instance|
            allow(instance).to receive(:check?).and_return(false)
          end
        end

        it { is_expected.to be_falsey }
      end

      context 'when Elasticsearch is unreachable' do
        before do
          allow(described_class.default.client).to receive(:ping).and_raise(StandardError)
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#unsupported_version?' do
    using RSpec::Parameterized::TableSyntax

    subject { helper.unsupported_version? }

    where(:distribution, :version, :result) do
      'elasticsearch' | '6.8.23' | true
      'elasticsearch' | '7.17.0' | false
      'elasticsearch' | '8.0.0'  | false
      'opensearch'    | '1.3.3'  | false
      'opensearch'    | '2.1.0'  | false
    end

    before do
      allow(helper).to receive(:server_info).and_return(distribution: distribution, version: version)
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#vectors_supported?' do
    using RSpec::Parameterized::TableSyntax

    subject { helper.vectors_supported?(arg) }

    where(:arg, :distribution, :version, :result) do
      :elasticsearch  | 'elasticsearch' | '6.8.23' | false
      :elasticsearch  | 'elasticsearch' | '7.17.0' | false
      :elasticsearch  | 'elasticsearch' | '8.0.0'  | true
      :opensearch     | 'elasticsearch' | '8.0.0'  | false
      :opensearch     | 'opensearch'    | '1.3.3'  | false
      :opensearch     | 'opensearch'    | '2.1.0'  | false
    end

    before do
      allow(helper).to receive(:server_info).and_return(distribution: distribution, version: version)
    end

    with_them do
      it { is_expected.to eq(result) }
    end
  end

  describe '#klass_to_alias_name' do
    it 'returns results for every listed class' do
      described_class::ES_SEPARATE_CLASSES.each do |klass|
        expect(helper.klass_to_alias_name(klass: klass)).to eq(
          [Rails.application.class.module_parent_name.downcase, Rails.env, klass.name.underscore.pluralize].join('-')
        )
      end
    end

    it 'returns results for repository' do
      expect(helper.klass_to_alias_name(klass: Repository)).to eq(Repository.__elasticsearch__.index_name)
    end
  end

  describe '#pending_migrations?' do
    it 'returns true when there are pending migrations' do
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([:foo, :bar])
      expect(helper).to be_pending_migrations
    end

    it 'returns false when there are no pending migrations' do
      allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      expect(helper).not_to be_pending_migrations
    end
  end

  describe '#indexing_paused?' do
    it 'delegates to Gitlab::CurrentSettings.elasticsearch_pause_indexing?' do
      allow(::Gitlab::CurrentSettings).to receive(:elasticsearch_pause_indexing?).and_return(:stubbed_value)
      expect(helper.indexing_paused?).to eq(::Gitlab::CurrentSettings.elasticsearch_pause_indexing?)
    end
  end

  describe '#refresh_index', :elastic do
    subject(:refresh_index) { helper.refresh_index(index_name: index_name) }

    context 'when index_name is not provided' do
      let(:index_name) { nil }

      it 'refreshes all indexes' do
        expected_count = helper.standalone_indices_proxies.count + 1 # add the main index
        expect(helper.client.indices).to receive(:refresh).exactly(expected_count).times

        refresh_index
      end
    end

    context 'when index_name is provided' do
      let(:index_name) { 'gitlab-test-issues' }

      it 'refreshes a single index' do
        expect(helper.client.indices).to receive(:refresh).with(index: index_name)

        refresh_index
      end
    end

    context 'when an index does not exist' do
      let(:index_name) { 'non-existing-index' }

      it 'does not refresh the index' do
        expect(helper.client.indices).not_to receive(:refresh)

        refresh_index
      end
    end
  end

  describe '#reindex' do
    let(:from) { :from }
    let(:slice) { :slice }
    let(:max_slice) { :max_slice }
    let(:to) { :to }
    let(:wait_for_completion) { :wait_for_completion }
    let(:scroll) { '3h' }
    let(:result) { { 'task' => '8675-309' } }

    it 'passes correct arguments to Search::ReindexingService' do
      expect(::Search::ReindexingService).to receive(:execute).with(
        from: from, to: to, slice: slice, max_slices: max_slice,
        wait_for_completion: wait_for_completion, scroll: scroll
      ).and_return(result)

      expect(helper.reindex(from: from, to: to, slice: slice, max_slice: max_slice,
        wait_for_completion: wait_for_completion, scroll: scroll)).to eq(result['task'])
    end
  end

  describe '.build_es_id' do
    it 'returns a calculated es_id' do
      expect(described_class.build_es_id(es_type: 'project', target_id: 123)).to eq('project_123')
    end
  end

  describe '#remove_wikis_from_the_standalone_index' do
    include ElasticsearchHelpers
    before do
      set_elasticsearch_migration_to :reindex_wikis_to_fix_routing, including: true
    end

    context 'when container_type is other than Group or Project' do
      it 'not calls delete_by_query' do
        expect(helper.client).not_to receive(:delete_by_query)
        helper.remove_wikis_from_the_standalone_index(1, 'Random')
      end
    end

    context 'when container_type is either Project or Group' do
      let(:body) do
        { query: { bool: { filter: { term: { rid: rid } } } } }
      end

      let(:index) { Elastic::Latest::WikiConfig.index_name }

      context 'when namespace_routing_id is passed' do
        let(:container_id) { 1 }
        let(:container_type) { 'Group' }
        let(:namespace_routing_id) { 0 }
        let(:rid) { "wiki_#{container_type.downcase}_#{container_id}" }

        it 'calls delete_by_query with passed namespace_routing_id as routing' do
          expect(helper.client).to receive(:delete_by_query).with({ body: body, index: index, conflicts: 'proceed', routing: "n_#{namespace_routing_id}" })
          helper.remove_wikis_from_the_standalone_index(container_id, container_type, namespace_routing_id)
        end

        context 'when migration reindex_wikis_to_fix_routing is not finished' do
          before do
            set_elasticsearch_migration_to :reindex_wikis_to_fix_routing, including: false
          end

          it 'calls delete_by_query without routing' do
            expect(helper.client).to receive(:delete_by_query).with({ body: body, index: index, conflicts: 'proceed' })
            helper.remove_wikis_from_the_standalone_index(container_id, container_type, namespace_routing_id)
          end
        end
      end

      context 'when namespace_routing_id is not passed' do
        let(:container_id) { 1 }
        let(:container_type) { 'Project' }
        let(:rid) { "wiki_#{container_type.downcase}_#{container_id}" }

        it 'calls delete_by_query without routing' do
          expect(helper.client).to receive(:delete_by_query).with({ body: body, index: index, conflicts: 'proceed' })
          helper.remove_wikis_from_the_standalone_index(container_id, container_type)
        end
      end
    end
  end

  describe '#target_index_names' do
    let(:target_index) { nil }

    subject(:target_index_names) { helper.target_index_names(target: target_index) }

    context 'when alias exists' do
      before do
        allow(helper).to receive(:alias_exists?).and_return(true)
        allow(helper.client.indices).to receive(:get_alias).and_return(aliases)
      end

      context 'when a nil target is provided' do
        let(:aliases) do
          {
            "gitlab-test-20231129-200242-0002" => { "aliases" => { "gitlab-test" => { "is_write_index" => true } } },
            "gitlab-test-20231129-200242" => { "aliases" => { "gitlab-test" => { "is_write_index" => false } } }
          }
        end

        let(:index_regex) { /\Agitlab-test-[\d-]+\z/ }

        it 'uses the default target from target_name' do
          expect(target_index_names.keys).to contain_exactly(index_regex, index_regex)
          expect(target_index_names.values).to contain_exactly(true, false)
        end
      end

      context 'when a target is provided' do
        let(:aliases) do
          {
            "gitlab-test-projects-20231129-0002" =>
              { "aliases" => { "gitlab-test-projects" => { "is_write_index" => true } } },
            "gitlab-test-projects-20231129" =>
              { "aliases" => { "gitlab-test-projects" => { "is_write_index" => false } } }
          }
        end

        let(:target_index) { "gitlab-test-projects" }
        let(:index_regex) { /\Agitlab-test-projects-[\d-]+\z/ }

        it 'uses the target index' do
          expect(target_index_names.keys).to contain_exactly(index_regex, index_regex)
          expect(target_index_names.values).to contain_exactly(true, false)
        end
      end

      context 'when write index is not set' do
        let(:aliases) do
          {
            "gitlab-test-20231129-200242" => { "aliases" => { "gitlab-test" => {} } }
          }
        end

        let(:index_regex) { /\Agitlab-test-[\d-]+\z/ }

        it 'returns the write index as true' do
          expect(target_index_names.keys).to contain_exactly(index_regex)
          expect(target_index_names.values).to contain_exactly(true)
        end
      end
    end

    context 'when alias does not exist' do
      before do
        allow(helper).to receive(:alias_exists?).and_return(false)
      end

      it 'returns a hash with a single key value pair' do
        expect(helper.target_index_names(target: nil)).to match({ 'gitlab-test' => true })
      end
    end
  end
end
