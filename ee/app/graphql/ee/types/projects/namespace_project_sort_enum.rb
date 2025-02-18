# frozen_string_literal: true

module EE
  module Types
    module Projects
      module NamespaceProjectSortEnum
        extend ActiveSupport::Concern

        prepended do
          value 'STORAGE', 'Sort by excess repository storage size, descending order.',
            value: :excess_repo_storage_size_desc,
            deprecated: {
              reason: 'Please use EXCESS_REPO_STORAGE_SIZE_DESC',
              milestone: '16.9'
            }
          value 'EXCESS_REPO_STORAGE_SIZE_DESC', 'Sort by excess repository storage size, descending order.',
            value: :excess_repo_storage_size_desc
        end
      end
    end
  end
end
