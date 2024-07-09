# frozen_string_literal: true

module Search
  FoundMultiLineBlob = Struct.new(:path, :chunks, :file_url, :blame_url, :match_count_total, :match_count,
    :project_path)
end
