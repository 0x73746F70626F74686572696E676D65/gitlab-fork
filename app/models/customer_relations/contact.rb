# frozen_string_literal: true

class CustomerRelations::Contact < ApplicationRecord
  include Gitlab::SQL::Pattern
  include Sortable
  include StripAttribute

  self.table_name = "customer_relations_contacts"

  belongs_to :group, -> { where(type: Group.sti_name) }, foreign_key: 'group_id'
  belongs_to :organization, optional: true
  has_many :issue_contacts, inverse_of: :contact
  has_many :issues, through: :issue_contacts, inverse_of: :customer_relations_contacts

  strip_attributes! :phone, :first_name, :last_name

  enum state: {
    inactive: 0,
    active: 1
  }

  validates :group, presence: true
  validates :phone, length: { maximum: 32 }
  validates :first_name, presence: true, length: { maximum: 255 }
  validates :last_name, presence: true, length: { maximum: 255 }
  validates :email, length: { maximum: 255 }
  validates :description, length: { maximum: 1024 }
  validates :email, uniqueness: { case_sensitive: false, scope: :group_id }
  validate :validate_email_format
  validate :validate_root_group

  scope :order_scope_asc, ->(field) { order(arel_table[field].asc.nulls_last) }
  scope :order_scope_desc, ->(field) { order(arel_table[field].desc.nulls_last) }

  scope :order_by_organization_asc, -> { includes(:organization).order("customer_relations_organizations.name ASC NULLS LAST") }
  scope :order_by_organization_desc, -> { includes(:organization).order("customer_relations_organizations.name DESC NULLS LAST") }

  SAFE_ATTRIBUTES = %w[
    created_at
    description
    first_name
    group_id
    id
    last_name
    organization_id
    state
    updated_at
  ].freeze

  def hook_attrs
    attributes.slice(*SAFE_ATTRIBUTES)
  end

  def self.reference_prefix
    '[contact:'
  end

  def self.reference_prefix_quoted
    '["contact:'
  end

  def self.reference_postfix
    ']'
  end

  # Searches for contacts with a matching first name, last name, email or description.
  #
  # This method uses ILIKE on PostgreSQL
  #
  # query - The search query as a String
  #
  # Returns an ActiveRecord::Relation.
  def self.search(query)
    fuzzy_search(query, [:first_name, :last_name, :email, :description], use_minimum_char_limit: false)
  end

  def self.search_by_state(state)
    where(state: state)
  end

  def self.sort_by_field(field, direction)
    if direction == :asc
      order_scope_asc(field)
    else
      order_scope_desc(field)
    end
  end

  def self.sort_by_organization(direction)
    if direction == :asc
      order_by_organization_asc
    else
      order_by_organization_desc
    end
  end

  def self.sort_by_name
    order(Gitlab::Pagination::Keyset::Order.build(
      [
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'last_name',
          order_expression: arel_table[:last_name].asc,
          distinct: false
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'first_name',
          order_expression: arel_table[:first_name].asc,
          distinct: false
        ),
        Gitlab::Pagination::Keyset::ColumnOrderDefinition.new(
          attribute_name: 'id',
          order_expression: arel_table[:id].asc
        )
      ]))
  end

  def self.find_ids_by_emails(group, emails)
    raise ArgumentError, "Cannot lookup more than #{MAX_PLUCK} emails" if emails.length > MAX_PLUCK

    where(group: group).where('lower(email) in (?)', emails.map(&:downcase)).pluck(:id)
  end

  def self.exists_for_group?(group)
    return false unless group

    exists?(group: group)
  end

  def self.move_to_root_group(group)
    update_query = <<~SQL
      UPDATE #{CustomerRelations::IssueContact.table_name}
      SET contact_id = new_contacts.id
      FROM #{table_name} AS existing_contacts
      JOIN #{table_name} AS new_contacts ON new_contacts.group_id = :old_group_id AND LOWER(new_contacts.email) = LOWER(existing_contacts.email)
      WHERE existing_contacts.group_id = :new_group_id AND contact_id = existing_contacts.id
    SQL
    connection.execute(sanitize_sql([update_query, { old_group_id: group.root_ancestor.id, new_group_id: group.id }]))

    dupes_query = <<~SQL
      DELETE FROM #{table_name} AS existing_contacts
      USING #{table_name} AS new_contacts
      WHERE existing_contacts.group_id = :new_group_id AND new_contacts.group_id = :old_group_id AND LOWER(new_contacts.email) = LOWER(existing_contacts.email)
    SQL
    connection.execute(sanitize_sql([dupes_query, { old_group_id: group.root_ancestor.id, new_group_id: group.id }]))

    where(group: group).update_all(group_id: group.root_ancestor.id)
  end

  def self.counts_by_state
    group(:state).count
  end

  private

  def validate_email_format
    return unless email

    self.errors.add(:email, I18n.t(:invalid, scope: 'valid_email.validations.email')) unless ValidateEmail.valid?(self.email)
  end

  def validate_root_group
    return if group&.root?

    self.errors.add(:base, _('contacts can only be added to root groups'))
  end
end
