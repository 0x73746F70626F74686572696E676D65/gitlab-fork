# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Changelog::Config do
  include ProjectForksHelper

  let(:project) { build_stubbed(:project) }

  describe '.from_git' do
    it 'retrieves the configuration from Git' do
      allow(project.repository)
        .to receive(:changelog_config)
        .and_return("---\ndate_format: '%Y'")

      expect(described_class)
        .to receive(:from_hash)
        .with(project, { 'date_format' => '%Y' }, nil)

      described_class.from_git(project)
    end

    it 'returns the default configuration when no YAML file exists in Git' do
      allow(project.repository)
        .to receive(:changelog_config)
        .and_return(nil)

      expect(described_class)
        .to receive(:new)
        .with(project)

      described_class.from_git(project)
    end

    context 'when changelog is empty' do
      it 'returns the default configuration' do
        allow(project.repository)
          .to receive(:changelog_config)
          .and_return("")

        expect(described_class)
          .to receive(:new)
          .with(project)

        described_class.from_git(project)
      end
    end
  end

  describe '.from_hash' do
    it 'sets the configuration according to a Hash' do
      user1 = create(:user)
      user2 = create(:user)
      user3 = create(:user)
      group = create(:group, path: 'group')
      group2 = create(:group, path: 'group-path')
      group.add_developer(user1)
      group.add_developer(user2)
      group2.add_developer(user3)

      config = described_class.from_hash(
        project,
        {
          'date_format' => 'foo',
          'template' => 'bar',
          'categories' => { 'foo' => 'bar' },
          'tag_regex' => 'foo',
          'include_groups' => %w[group group-path non-existent-group]
        },
        user1
      )

      expect(config.date_format).to eq('foo')
      expect(config.template)
        .to be_instance_of(Gitlab::TemplateParser::AST::Expressions)

      expect(config.categories).to eq({ 'foo' => 'bar' })
      expect(config.tag_regex).to eq('foo')
      expect(config.always_credit_user_ids).to match_array([user1.id, user2.id, user3.id])
    end

    it 'raises Error when the categories are not a Hash' do
      expect { described_class.from_hash(project, 'categories' => 10) }
        .to raise_error(Gitlab::Changelog::Error)
    end

    it 'raises a Gitlab::Changelog::Error when the template is invalid' do
      invalid_template = <<~TPL
        {% each {{foo}} %}
        {% end %}
      TPL

      expect { described_class.from_hash(project, 'template' => invalid_template) }
        .to raise_error(Gitlab::Changelog::Error)
    end
  end

  describe '#contributor?' do
    let(:project) { create(:project, :public, :repository) }

    context 'when user is a member of project' do
      let(:user) { create(:user) }

      before do
        project.add_developer(user)
      end

      it { expect(described_class.new(project).contributor?(user)).to eq(false) }
    end

    context 'when user has at least one merge request merged into default_branch' do
      let(:contributor) { create(:user) }
      let(:user_without_access) { create(:user) }
      let(:user_fork) { fork_project(project, contributor, repository: true) }

      before do
        create(:merge_request, :merged,
               author: contributor,
               target_project: project,
               source_project: user_fork,
               target_branch: project.default_branch.to_s)
      end

      it { expect(described_class.new(project).contributor?(contributor)).to eq(true) }
      it { expect(described_class.new(project).contributor?(user_without_access)).to eq(false) }
    end
  end

  describe '#category' do
    it 'returns the name of a category' do
      config = described_class.new(project)

      config.categories['foo'] = 'Foo'

      expect(config.category('foo')).to eq('Foo')
    end

    it 'returns the raw category name when no alternative name is configured' do
      config = described_class.new(project)

      expect(config.category('bla')).to eq('bla')
    end
  end

  describe '#format_date' do
    it 'formats a date according to the configured date format' do
      config = described_class.new(project)
      time = Time.utc(2021, 1, 5)

      expect(config.format_date(time)).to eq('2021-01-05')
    end
  end

  describe '#always_credit_author?' do
    let_it_be(:group_member) { create(:user) }
    let_it_be(:non_group_member) { create(:user) }
    let_it_be(:group) { create(:group, :private, path: 'group') }

    before do
      group.add_developer(group_member)
    end

    context 'when include_groups is defined' do
      context 'when user generating changelog has access to group' do
        it 'returns whether author should always be credited' do
          config = described_class.from_hash(
            project,
            { 'include_groups' => ['group'] },
            group_member
          )

          expect(config.always_credit_author?(group_member)).to eq(true)
          expect(config.always_credit_author?(non_group_member)).to eq(false)
        end
      end

      context 'when user generating changelog has no access to group' do
        it 'always returns false' do
          config = described_class.from_hash(
            project,
            { 'include_groups' => ['group'] },
            non_group_member
          )

          expect(config.always_credit_author?(group_member)).to eq(false)
          expect(config.always_credit_author?(non_group_member)).to eq(false)
        end
      end
    end

    context 'when include_groups is not defined' do
      it 'always returns false' do
        config = described_class.from_hash(
          project,
          {},
          group_member
        )

        expect(config.always_credit_author?(group_member)).to eq(false)
        expect(config.always_credit_author?(non_group_member)).to eq(false)
      end
    end
  end
end
