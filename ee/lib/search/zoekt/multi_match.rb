# frozen_string_literal: true

module Search
  module Zoekt
    class MultiMatch
      MAX_CHUNKS_PER_FILE = 50
      DEFAULT_REQUESTED_CHUNK_SIZE = 3
      NEW_CHUNK_THRESHOLD = 2
      HIGHLIGHT_START_TAG = 'gitlabzoekt→'
      HIGHLIGHT_END_TAG = '←gitlabzoekt'

      def initialize(requested_chunk_size = DEFAULT_REQUESTED_CHUNK_SIZE)
        requested_chunk_size ||= DEFAULT_REQUESTED_CHUNK_SIZE
        @max_chunks_size = requested_chunk_size.clamp(0, MAX_CHUNKS_PER_FILE)
      end

      def blobs_for_project(result, project, ref)
        Search::FoundMultiLineBlob.new(
          path: result[:path],
          chunks: result[:chunks],
          project_path: project.full_path,
          file_url: Gitlab::Routing.url_helpers.project_blob_url(project, File.join(ref, result[:path])),
          blame_url: Gitlab::Routing.url_helpers.project_blame_url(project, File.join(ref, result[:path])),
          match_count_total: result[:match_count_total],
          match_count: result[:match_count]
        )
      end

      def zoekt_extract_result_pages_multi_match(response, per_page, page_limit)
        i = 0
        results = {}
        response.each_file do |file|
          current_page = i / per_page
          break false if current_page == page_limit

          results[current_page] ||= []
          chunks, match_count = chunks_for_each_file_with_limited_match_count(file[:LineMatches])
          results[current_page] << {
            path: file[:FileName],
            project_id: file[:Repository].to_i,
            chunks: chunks,
            match_count_total: file[:LineMatches].inject(0) { |sum, line| sum + line[:LineFragments].count },
            match_count: match_count
          }
          i += 1
        end
        results
      end

      private

      def chunks_for_each_file_with_limited_match_count(linematches)
        chunks = []
        generate_chunk = true # It is set to true at the start to generate the first chunk
        chunk = { lines: {}, match_count_in_chunk: 0 }
        limited_match_count_per_file = 0
        linematches.each.with_index do |match, count_idx|
          next if match[:FileName]

          if generate_chunk
            chunk = { lines: {}, match_count_in_chunk: 0 }
            # Generate lines before the match for the context
            # It is conditional because we don't want to run this for the first line of code or
            # difference between current matched line and previous matched line is less than CONTEXT_LINES_COUNT
            if show_previous_blobs?(match[:LineNumber], linematches, count_idx)
              generate_context_blobs(match, chunk, :before)
            end
          end

          chunk[:lines][match[:LineNumber]] = {
            text: Base64.decode64(match[:Line]).force_encoding('UTF-8'),
            rich_text: highlight_match(match[:Line], match[:LineFragments])
          }
          match_count_per_line = match[:LineFragments].count
          chunk[:match_count_in_chunk] += match_count_per_line
          # Generate lines after the match for the context
          generate_context_blobs(match, chunk, :after)
          generate_chunk = linematches[count_idx.next].nil? ||
            (linematches[count_idx.next][:LineNumber] - match[:LineNumber]).abs > NEW_CHUNK_THRESHOLD

          if generate_chunk
            limited_match_count_per_file += chunk[:match_count_in_chunk]
            chunks << transform_chunk(chunk)
          end

          break if chunks.count == @max_chunks_size
        end
        [chunks, limited_match_count_per_file]
      end

      def show_previous_blobs?(line_number, line_matches, idx)
        line_number != 1 &&
          (line_number - line_matches[idx.pred][:LineNumber]).abs > Gitlab::Search::Zoekt::Client::CONTEXT_LINES_COUNT
      end

      def generate_context_blobs(match, chunk, context)
        context_encoded_string = if context == :before
                                   match[:Before]
                                 else
                                   match[:After]
                                 end

        decoded_context_array = if context_encoded_string.empty?
                                  [context_encoded_string]
                                else
                                  Base64.decode64(context_encoded_string).split("\n", -1)
                                end

        if context == :before
          decoded_context_array.reverse_each.with_index(1) do |line, line_idx|
            unless chunk[:lines][match[:LineNumber] - line_idx]
              chunk[:lines][match[:LineNumber] - line_idx] =
                { text: line.force_encoding('UTF-8'), rich_text: line.force_encoding('UTF-8') }
            end
          end
        else
          decoded_context_array.each.with_index(1) do |line, line_idx|
            unless chunk[:lines][match[:LineNumber] + line_idx]
              chunk[:lines][match[:LineNumber] + line_idx] =
                { text: line.force_encoding('UTF-8'), rich_text: line.force_encoding('UTF-8') }
            end
          end
        end
      end

      def transform_chunk(chunk)
        {
          match_count_in_chunk: chunk[:match_count_in_chunk],
          lines: chunk[:lines].sort.map do |e|
            { line_number: e[0], text: e[1][:text], rich_text: e[1][:rich_text] }
          end
        }
      end

      def highlight_match(match_line, match_line_fragments)
        ranges = match_line_fragments.map do |fragment|
          fragment[:LineOffset]..(fragment[:LineOffset] + fragment[:MatchLength] - 1)
        end
        line = Gitlab::StringRangeMarker.new(Base64.decode64(match_line).force_encoding('UTF-8')).mark(ranges) do |text|
          "#{HIGHLIGHT_START_TAG}#{text}#{HIGHLIGHT_END_TAG}"
        end
        replacements = { HIGHLIGHT_START_TAG => '<b>', HIGHLIGHT_END_TAG => '</b>' }
        escaped_line = html_escape_once(line)
        escaped_line.gsub(%r{(#{HIGHLIGHT_START_TAG}|#{HIGHLIGHT_END_TAG})}o, replacements)
      end
    end
  end
end
