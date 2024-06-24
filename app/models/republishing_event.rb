class RepublishingEvent < ApplicationRecord
  belongs_to :user

  validates :action, presence: true
  validates :reason, presence: true
  validates :bulk, inclusion: [true, false]
  validates :content_id, presence: true, unless: -> { bulk }
  validates :bulk_content_type, presence: true, if: -> { bulk }

  validates :content_type, presence: true, if: -> { bulk_content_type == "all_by_type" }
  validates :content_type, absence: true, unless: -> { bulk_content_type == "all_by_type" }

  validates :organisation_id, presence: true, if: -> { bulk_content_type == "all_documents_by_organisation" }
  validates :organisation_id, absence: true, unless: -> { bulk_content_type == "all_documents_by_organisation" }

  validates :content_ids, presence: true, if: -> { bulk_content_type == "all_documents_by_content_ids" }
  validates :content_ids, absence: true, unless: -> { bulk_content_type == "all_documents_by_content_ids" }
  validate :content_ids_is_a_non_empty_array_of_strings, if: -> { bulk_content_type == "all_documents_by_content_ids" }

  enum :bulk_content_type, %i[
    all_documents
    all_documents_with_pre_publication_editions
    all_documents_with_pre_publication_editions_with_html_attachments
    all_documents_with_publicly_visible_editions_with_attachments
    all_documents_with_publicly_visible_editions_with_html_attachments
    all_published_organisation_about_us_pages
    all_by_type
    all_documents_by_organisation
    all_documents_by_content_ids
  ]

  def content_ids_is_a_non_empty_array_of_strings
    return errors.add(:content_ids, "is not an array") unless content_ids.is_a?(Array)
    return errors.add(:content_ids, "is not a non-empty array") if content_ids.empty?

    errors.add(:content_ids, "is not a non-empty array of strings") unless content_ids.all? { |content_id| content_id.is_a?(String) }
  end
end
