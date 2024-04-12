# frozen_string_literal: true

require 'nokogiri'

module MarkupHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Context

  # Use this in places where you would normally use link_to(gfm(...), ...).
  def link_to_markdown(body, url, html_options = {})
    return '' if body.blank?

    link_to_html(markdown(body, pipeline: :single_line), url, html_options)
  end

  def link_to_markdown_field(object, field, url, html_options = {})
    rendered_field = markdown_field(object, field)

    link_to_html(rendered_field, url, html_options)
  end

  # It solves a problem occurring with nested links (i.e.
  # "<a>outer text <a>gfm ref</a> more outer text</a>"). This will not be
  # interpreted as intended. Browsers will parse something like
  # "<a>outer text </a><a>gfm ref</a> more outer text" (notice the last part is
  # not linked any more). link_to_html corrects that. It wraps all parts to
  # explicitly produce the correct linking behavior (i.e.
  # "<a>outer text </a><a>gfm ref</a><a> more outer text</a>").
  def link_to_html(redacted, url, html_options = {})
    fragment = Nokogiri::HTML::DocumentFragment.parse(redacted)

    if fragment.children.size == 1 && fragment.children[0].name == 'a'
      # Fragment has only one node, and it's a link generated by `gfm`.
      # Replace it with our requested link.
      text = fragment.children[0].text
      fragment.children[0].replace(link_to(text, url, html_options))
    else
      # Traverse the fragment's first generation of children looking for
      # either pure text or emojis, wrapping anything found in the
      # requested link
      fragment.children.each do |node|
        if node.text?
          node.replace(link_to(node.text, url, html_options))
        elsif node.name == 'gl-emoji'
          node.replace(link_to(node.to_html.html_safe, url, html_options))
        end
      end
    end

    # Add any custom CSS classes to the GFM-generated reference links
    if html_options[:class]
      fragment.css('a.gfm').add_class(html_options[:class])
    end

    fragment.to_html.html_safe
  end

  # Return the first line of +text+, up to +max_chars+, after parsing the line
  # as Markdown.  HTML tags in the parsed output are not counted toward the
  # +max_chars+ limit.  If the length limit falls within a tag's contents, then
  # the tag contents are truncated without removing the closing tag.
  def first_line_in_markdown(object, attribute, max_chars = nil, **options)
    md = markdown_field(object, attribute, options.merge(post_process: false))
    return unless md.present?

    tags = %w[a gl-emoji b strong i em pre code p span]

    context = markdown_field_render_context(object, attribute, options)
    context.reverse_merge!(truncate_visible_max_chars: max_chars || md.length)

    text = prepare_for_rendering(md, context)
    text = sanitize(
      text,
      tags: tags,
      attributes: Rails::Html::WhiteListSanitizer.allowed_attributes +
        %w[
          style data-src data-name data-unicode-version data-html data-fallback-src
          data-reference-type data-project-path data-iid data-mr-title
          data-user
        ]
    )

    render_links(text)
  end

  def markdown(text, context = {})
    return '' unless text.present?

    context[:project] ||= @project
    context[:group] ||= @group

    html = Markup::RenderingService.new(text, context: context, postprocess_context: postprocess_context).execute

    Hamlit::RailsHelpers.preserve(html)
  end

  def markdown_field(object, field, context = {})
    object = object.for_display if object.respond_to?(:for_display)
    return '' unless object.present?

    redacted_field_html = object.try(:"redacted_#{field}_html")
    return redacted_field_html if redacted_field_html

    render_markdown_field(object, field, context)
  end

  def markup(file_name, text, context = {})
    context[:project] ||= @project
    context[:text_source] ||= :blob
    prepare_asciidoc_context(file_name, context)

    html = Markup::RenderingService
             .new(text, file_name: file_name, context: context, postprocess_context: postprocess_context)
             .execute

    Hamlit::RailsHelpers.preserve(html)
  end

  def render_wiki_content(wiki_page, context = {})
    text = wiki_page.content
    return '' unless text.present?

    context = render_wiki_content_context(wiki_page.wiki, wiki_page, context)
    prepare_asciidoc_context(wiki_page.path, context)

    html = Markup::RenderingService
             .new(text, file_name: wiki_page.path, context: context, postprocess_context: postprocess_context)
             .execute

    Hamlit::RailsHelpers.preserve(html)
  end

  # Returns the text necessary to reference `entity` across projects
  #
  # project - Project to reference
  # entity  - Object that responds to `to_reference`
  #
  # Examples:
  #
  #   cross_project_reference(project, project.issues.first)
  #   # => 'namespace1/project1#123'
  #
  #   cross_project_reference(project, project.merge_requests.first)
  #   # => 'namespace1/project1!345'
  #
  # Returns a String
  def cross_project_reference(project, entity)
    if entity.respond_to?(:to_reference)
      entity.to_reference(project, full: true)
    else
      ''
    end
  end

  private

  def render_wiki_content_context(wiki, wiki_page, context)
    context.merge(
      pipeline: :wiki,
      wiki: wiki,
      repository: wiki.repository,
      page_slug: wiki_page.slug,
      issuable_reference_expansion_enabled: true,
      requested_path: wiki_page.path
    ).merge(render_wiki_content_context_container(wiki))
  end

  def render_wiki_content_context_container(wiki)
    { project: wiki.container }
  end

  # Sanitize and style user references links
  #
  # @param String text the string to be sanitized
  #
  # 1. Remove empty <a> tags which are caused by the <img> tags being stripped
  #   (as our markdown wraps images in links)
  # 2. Strip all link tags, except user references, leaving just the link text
  # 3. Add a highlight class for current user's references
  #
  # @return sanitized HTML string
  def render_links(text)
    scrubber = Loofah::Scrubber.new do |node|
      next unless node.name == 'a'
      next node.remove if node.children.empty?
      next node.replace(node.children) if node['data-reference-type'] != 'user'
      next node.append_class('current-user') if current_user && node['data-user'] == current_user.id.to_s
    end

    sanitize text, scrubber: scrubber
  end

  def markdown_toolbar_button(options = {})
    data = options[:data].merge({ container: 'body' })
    css_classes = %w[js-md has-tooltip] << options[:css_class].to_s

    render Pajamas::ButtonComponent.new(
      category: :tertiary,
      size: :small,
      icon: options[:icon],
      button_options: {
        class: css_classes.join(' '),
        data: data,
        title: options[:title],
        aria: {
          label: options[:title]
        }
      }
    )
  end

  def render_markdown_field(object, field, context = {})
    post_process = context.delete(:post_process)
    post_process = true if post_process.nil?

    html = Banzai.render_field(object, field, context)

    return html unless post_process

    prepare_for_rendering(html, markdown_field_render_context(object, field, context))
  end

  def markdown_field_render_context(object, field, base_context = {})
    return base_context unless object.respond_to?(:banzai_render_context)

    base_context.reverse_merge(object.banzai_render_context(field))
  end

  def prepare_for_rendering(html, context = {})
    return '' unless html.present?

    context.reverse_merge!(postprocess_context)

    html = Banzai.post_process(html, context)

    Hamlit::RailsHelpers.preserve(html)
  end

  def postprocess_context
    {
      current_user: (current_user if defined?(current_user)),

      # RepositoryLinkFilter and UploadLinkFilter
      commit: @commit,
      wiki: @wiki,
      ref: @ref,
      requested_path: @path
    }
  end

  def prepare_asciidoc_context(file_name, context)
    return unless Gitlab::MarkupHelper.asciidoc?(file_name)

    context.reverse_merge!(commit: @commit, ref: @ref, requested_path: @path)
  end

  extend self
end

MarkupHelper.prepend_mod_with('MarkupHelper')
