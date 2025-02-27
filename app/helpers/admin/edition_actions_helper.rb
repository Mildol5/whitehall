module Admin::EditionActionsHelper
  def edit_edition_button(edition)
    link_to "Edit draft", edit_admin_edition_path(edition), title: "Edit #{edition.title}", class: "btn btn-default btn-lg add-left-margin"
  end

  def redraft_edition_button(edition)
    button_to "Create new edition to edit", revise_admin_edition_path(edition), title: "Create new edition to edit", class: "btn btn-default btn-lg"
  end

  def content_data_button(edition)
    url = content_data_page_data_url(edition)

    link_to "View data about page",
            url,
            class: "btn btn-default btn-lg pull-right",
            data: {
              track_category: "external-link-clicked",
              track_action: url,
              track_label: "View data about page",
            }
  end

  def custom_track_dimensions(edition, edition_taxons)
    {
      1 => edition.public_path,
      2 => edition.type.underscore,
      3 => root_taxon_paths(edition_taxons),
      4 => edition.document.content_id,
    }
  end

  def approve_retrospectively_edition_button(edition)
    confirmation_prompt = "Are you sure you want to retrospectively approve this document?"
    tag.div(class: "approve_retrospectively_button") do
      capture do
        form_for [:admin, edition], url: approve_retrospectively_admin_edition_path(edition, lock_version: edition.lock_version), method: :post do |form|
          concat(form.submit("Looks good", data: { confirm: confirmation_prompt }, class: "btn btn-success"))
        end
      end
    end
  end

  def submit_edition_button(edition)
    button_to "Submit for 2nd eyes", submit_admin_edition_path(edition, lock_version: edition.lock_version), class: "btn btn-success second-eyes"
  end

  def reject_edition_button(edition)
    button_to "Reject", reject_admin_edition_path(edition, lock_version: edition.lock_version), class: "btn btn-warning"
  end

  def publish_edition_form(edition, options = {})
    button_title = "Publish #{edition.title}"

    if options[:force]
      link_to(
        "Force publish",
        confirm_force_publish_admin_edition_path(edition, lock_version: edition.lock_version),
        title: button_title,
        class: "btn btn-default force-publish",
      )
    else
      button_to(
        "Publish",
        confirm_publish_admin_edition_path(edition, lock_version: edition.lock_version),
        title: button_title,
        class: "btn btn-success publish",
      )
    end
  end

  def schedule_edition_form(edition, options = {})
    button_title = "Schedule #{edition.title} for publication on #{l edition.scheduled_publication, format: :long}"

    if options[:force]
      button_to(
        "Force schedule",
        force_schedule_admin_edition_path(edition, lock_version: edition.lock_version),
        data: { confirm: "Are you sure you want to force schedule this document for publication?" },
        title: button_title,
        class: "btn btn-warning",
      )
    else
      button_to(
        "Schedule",
        schedule_admin_edition_path(edition, lock_version: edition.lock_version),
        title: button_title,
        class: "btn btn-success",
      )
    end
  end

  def unschedule_edition_button(edition)
    confirm = "Are you sure you want to unschedule this edition and return it to the submitted state?"
    button_to "Unschedule",
              unschedule_admin_edition_path(edition, lock_version: edition.lock_version),
              title: "Unschedule this edition to allow changes or prevent automatic publication on #{l edition.scheduled_publication, format: :long}",
              class: "btn btn-warning",
              data: { confirm: }
  end

  def delete_edition_button(edition)
    link_to "Discard draft", confirm_destroy_admin_edition_path(edition), method: :get, class: "btn btn-danger"
  end

  def filter_edition_type_options_for_select(user, selected)
    options_for_select([["All types", ""]]) + edition_type_options_for_select(user, selected) + edition_sub_type_options_for_select(selected)
  end

  def filter_edition_type_opt_groups(user, selected)
    [
      [
        "",
        [
          {
            text: "All types",
            value: "",
            selected: selected.blank?,
          },
        ],
      ],
      [
        "Types",
        type_options_container(user).map do |text, value|
          {
            text:,
            value:,
            selected: selected == value,
          }
        end,
      ],
      [
        "Publication sub-types",
        PublicationType.ordered_by_prevalence.map do |sub_type|
          value = "publication_#{sub_type.id}"
          {
            text: sub_type.plural_name,
            value:,
            selected: selected == value,
          }
        end,
      ],
      [
        "News article sub-types",
        NewsArticleType.all.map do |sub_type|
          value = "news_article_#{sub_type.id}"
          {
            text: sub_type.plural_name,
            value:,
            selected: selected == value,
          }
        end,
      ],
      [
        "Speech sub-types",
        SpeechType.all.map do |sub_type|
          value = "speech_#{sub_type.id}"
          {
            text: sub_type.plural_name,
            value:,
            selected: selected == value,
          }
        end,
      ],
    ]
  end

private

  def edition_type_options_for_select(user, selected)
    options_for_select(type_options_container(user), selected)
  end

  def type_options_container(user)
    Whitehall.edition_classes.map { |edition_type|
      next if edition_type == FatalityNotice && !user.can_handle_fatalities?

      [edition_type.format_name.humanize.pluralize, edition_type.model_name.singular]
    }.compact
  end

  def edition_sub_type_options_for_select(selected)
    subtype_options_hash = {
      "Publication sub-types" => PublicationType.ordered_by_prevalence.map { |sub_type| [sub_type.plural_name, "publication_#{sub_type.id}"] },
      "News article sub-types" => NewsArticleType.all.map { |sub_type| [sub_type.plural_name, "news_article_#{sub_type.id}"] },
      "Speech sub-types" => SpeechType.all.map { |sub_type| [sub_type.plural_name, "speech_#{sub_type.id}"] },
    }
    grouped_options_for_select(subtype_options_hash, selected)
  end

  def root_taxon_paths(edition_taxons)
    edition_taxons
      .map(&method(:get_root))
      .map(&:base_path)
      .uniq
      .map(&method(:delete_leading_slash))
      .sort.join(", ")
  end

  def delete_leading_slash(str)
    str.delete_prefix("/")
  end

  def get_root(taxon)
    return taxon if taxon.parent_node.nil?

    get_root(taxon.parent_node)
  end
end
