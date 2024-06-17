# frozen_string_literal: true

RSpec.shared_examples 'basic epic and work item attributes in sync' do
  it 'sets the same basic epic data to the work item', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    expect(epic).to be_persisted
    expect(work_item).to be_valid

    expect(work_item.work_item_type.name).to eq('Epic')
    expect(work_item.namespace).to eq(epic.group)
    expect(work_item.title).to eq epic.title
    expect(work_item.title_html).to eq epic.title_html
    expect(work_item.description).to eq epic.description
    expect(work_item.description_html).to eq epic.description_html
    expect(work_item.updated_by).to eq epic.updated_by
    expect(work_item.last_edited_by).to eq epic.last_edited_by
    expect(work_item.last_edited_at).to eq epic.last_edited_at
    expect(work_item.closed_by).to eq epic.closed_by
    expect(work_item.closed_at).to eq epic.closed_at
    expect(work_item.confidential).to eq epic.confidential
    expect(work_item.iid).to eq(epic.iid)
    expect(work_item.state).to eq(epic.state)
    expect(work_item.author).to eq(epic.author)
    expect(work_item.created_at).to eq(epic.created_at)
    expect(work_item.updated_at).to eq(epic.updated_at)
    expect(work_item.state).to eq(epic.state)
    expect(work_item.external_key).to eq(epic.external_key)
    expect(work_item.lock_version).to eq(epic.lock_version)
    expect(work_item.relative_position).to eq(epic.id)
  end
end

RSpec.shared_examples 'syncs all data from an epic to a work item' do
  it_behaves_like 'basic epic and work item attributes in sync'

  it 'sets the same epic data to the work item association', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    if work_item.color.present?
      expect(work_item.color.color).to eq(epic.color)
    else
      expect(epic.color).to eq(Epic::DEFAULT_COLOR)
    end

    if epic.parent
      expect(work_item.work_item_parent).to eq(epic.parent.work_item)
      expect(work_item.work_item_parent.updated_at).to eq(epic.parent.updated_at)
      expect(work_item.parent_link.relative_position).to eq(epic.relative_position)
    else
      expect(work_item.work_item_parent).to be_nil
    end

    if epic.start_date_is_fixed || work_item.dates_source
      # DateSource requires start_date_is_fixed to be set, while epics allow `nil` which is the equivalent to false
      expect(work_item.dates_source.start_date_is_fixed).to eq(!!epic.start_date_is_fixed)
      expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
    end

    if epic.due_date_is_fixed || work_item.dates_source
      # DateSource requires due_date_is_fixed to be set, while epics allow `nil` which is the equivalent to false
      expect(work_item.dates_source.due_date_is_fixed).to eq(!!epic.due_date_is_fixed)
      expect(work_item.dates_source.due_date_fixed).to eq(epic.due_date_fixed)
    end

    if epic.unauthorized_related_epics
      related_epic_issue_ids = epic.unauthorized_related_epics.map(&:issue_id)
      related_work_item_ids = work_item.related_issues(authorize: false).map(&:id)

      related_epic_updated_at = epic.unauthorized_related_epics.map(&:updated_at)
      related_work_item_updated_at = work_item.related_issues(authorize: false).map(&:updated_at)

      expect(related_work_item_ids).to match(related_epic_issue_ids)
      expect(related_epic_updated_at).to match(related_work_item_updated_at)
    end

    # Data we do not want to sync yet
    expect(work_item.notes).to be_empty
    expect(work_item.labels).to be_empty
  end
end

RSpec.shared_examples 'syncs all data from a work_item to an epic' do
  it_behaves_like 'basic epic and work item attributes in sync'

  it 'sets the same epic data to the work item association', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    if epic.color == Epic::DEFAULT_COLOR
      expect(work_item.color).to be_nil
    else
      expect(work_item.color.color).to eq(epic.color)
    end

    if epic.parent
      expect(work_item.work_item_parent).to eq(epic.parent.work_item)
      expect(work_item.parent_link.relative_position).to eq(epic.relative_position)
    else
      expect(work_item.work_item_parent).to be_nil
    end

    if epic.start_date_is_fixed || work_item.dates_source
      expect(work_item.dates_source.start_date_is_fixed).to eq(epic.start_date_is_fixed)
      expect(work_item.dates_source.start_date_fixed).to eq(epic.start_date_fixed)
    end

    if epic.due_date_is_fixed || work_item.dates_source
      expect(work_item.dates_source.due_date_is_fixed).to eq(epic.due_date_is_fixed)
      expect(work_item.dates_source.due_date_fixed).to eq(epic.due_date_fixed)
    end

    if epic.unauthorized_related_epics
      related_epic_issue_ids = epic.unauthorized_related_epics.map(&:issue_id)
      related_work_item_ids = work_item.related_issues(authorize: false).map(&:id)

      expect(related_work_item_ids).to match(related_epic_issue_ids)
    end

    # Data we do not want to sync yet
    expect(epic.notes).to be_empty
    expect(epic.labels).to be_empty
  end
end

RSpec.shared_examples 'syncs labels between epics and epic work items' do
  it 'returns same labels for epic and epic work item', :aggregate_failures do
    subject

    epic.reload
    work_item = epic.work_item

    expect(epic.labels).to eq(work_item.labels)

    expect(epic.labels).to match_array(expected_labels)
    expect(epic.own_labels).to match_array(expected_epic_own_labels)
    expect(epic.work_item.own_labels).to match_array(expected_epic_work_item_own_labels)
  end
end
