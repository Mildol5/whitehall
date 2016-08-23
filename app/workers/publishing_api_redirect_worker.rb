class PublishingApiRedirectWorker < PublishingApiWorker
  def perform(content_id, destination, locale, allow_draft = false)
    Whitehall.publishing_api_v2_client.unpublish(
      content_id,
      type: "redirect",
      locale: locale,
      alternative_path: destination.strip,
      allow_draft: allow_draft
    )
  end
end
