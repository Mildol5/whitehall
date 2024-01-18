require "test_helper"
require "gds_api/test_helpers/publishing_api"

class PublishingApiDocumentRepublishingWorkerTest < ActiveSupport::TestCase
  extend Minitest::Spec::DSL
  include GdsApi::TestHelpers::PublishingApi

  let(:document) { create(:document, editions: [live_edition, draft_edition].compact) }

  context "when the document has a published edition and a draft edition" do
    let(:live_edition) { build(:published_edition) }
    let(:draft_edition) { build(:draft_edition) }

    it "publishes the live edition, then pushes the draft" do
      # This sequence asserts that the Publishing API is called in the correct order.
      # It's important to republish the 'published' edition first, then push the draft afterwards.
      publish_then_draft = sequence("publish_then_draft")

      Whitehall::PublishingApi
        .expects(:patch_links)
        .with(live_edition, bulk_publishing: false)

      Whitehall::PublishingApi
        .expects(:publish)
        .with(live_edition, "republish", bulk_publishing: false)
        .in_sequence(publish_then_draft)

      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(live_edition, "republish")
        .in_sequence(publish_then_draft)

      Whitehall::PublishingApi
        .expects(:save_draft)
        .with(draft_edition, "republish", bulk_publishing: false)
        .in_sequence(publish_then_draft)

      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(draft_edition, "republish")
        .in_sequence(publish_then_draft)

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end

    context "when a draft edition is present and invalid" do
      let(:draft_edition) { build(:draft_edition, change_note: nil, minor_change: false) }

      it "republishes the live edition, but doesn't republish the draft edition" do
        Whitehall::PublishingApi
        .expects(:patch_links)
        .with(live_edition, bulk_publishing: false)

        Whitehall::PublishingApi
          .expects(:publish)
          .with(live_edition, "republish", bulk_publishing: false)

        ServiceListeners::PublishingApiHtmlAttachments
          .expects(:process)
          .with(live_edition, "republish")

        Whitehall::PublishingApi
          .expects(:save_draft)
          .with(draft_edition, "republish", bulk_publishing: false)
          .never

        ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(draft_edition, "republish")
        .never

        PublishingApiDocumentRepublishingWorker.new.perform(document.id)
      end
    end
  end

  context "when the document is published with no draft" do
    let(:live_edition) { build(:published_edition) }
    let(:draft_edition) { nil }

    it "publishes the live edition" do
      Whitehall::PublishingApi
        .expects(:patch_links)
        .with(live_edition, bulk_publishing: false)

      Whitehall::PublishingApi
        .expects(:publish)
        .with(live_edition, "republish", bulk_publishing: false)

      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(live_edition, "republish")

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end
  end

  context "when the document is draft and there is no published edition" do
    let(:live_edition) { nil }
    let(:draft_edition) { build(:draft_edition) }

    it "pushes the draft edition" do
      Whitehall::PublishingApi
        .expects(:patch_links)
        .with(draft_edition, bulk_publishing: false)

      Whitehall::PublishingApi
        .expects(:save_draft)
        .with(draft_edition, "republish", bulk_publishing: false)

      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(draft_edition, "republish")

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end
  end

  context "when the document has been withdrawn" do
    let(:live_edition) { build(:withdrawn_edition) }
    let(:draft_edition) { nil }

    it "publishes the live edition, then immediately withdraws it" do
      publish_then_withdraw = sequence("publish_then_withdraw")

      Whitehall::PublishingApi
        .expects(:patch_links)
        .with(live_edition, bulk_publishing: false)

      PublishingApiUnpublishingWorker
        .expects(:new)
        .returns(unpublishing_worker = mock)

      # 1. Republish as 'published'
      Whitehall::PublishingApi
        .expects(:publish)
        .with(live_edition, "republish", bulk_publishing: false)
        .in_sequence(publish_then_withdraw)

      # 2. Republish HTML attachments as 'published'
      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(live_edition, "republish")
        .in_sequence(publish_then_withdraw)

      # 3. Withdraw the newly published edition
      unpublishing_worker
        .expects(:perform)
        .with(document.live_edition.unpublishing.id, false)
        .in_sequence(publish_then_withdraw)

      # 4. Withdraw HTML attachments
      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(live_edition, "republish")
        .in_sequence(publish_then_withdraw)

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end
  end

  context "when the document has been unpublished" do
    let(:live_edition) { build(:unpublished_edition) }
    let(:draft_edition) { nil }

    it "unpublishes the document" do
      unpublish = sequence("unpublish")

      PublishingApiUnpublishingWorker
        .expects(:new)
        .returns(unpublishing_worker = mock)

      # 1. Re-send the unpublishing
      unpublishing_worker
        .expects(:perform)
        .with(document.latest_edition.unpublishing.id, false)
        .in_sequence(unpublish)

      # 2. Push HTML attachments
      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(document.latest_edition, "republish")
        .in_sequence(unpublish)

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end
  end

  context "when the document has been unpublished, and it has a new draft" do
    let(:live_edition) { build(:unpublished_edition) }
    let(:draft_edition) { build(:draft_edition) }

    it "unpublishes the document, then pushes the new draft" do
      unpublish_then_send_draft = sequence("unpublish_then_send_draft")

      Whitehall::PublishingApi
        .expects(:patch_links)
        .with(document.latest_edition, bulk_publishing: false)

      PublishingApiUnpublishingWorker
        .expects(:new)
        .returns(unpublishing_worker = mock)

      unpublished_edition = document.editions.unpublished.last

      # 1. Re-send the unpublishing
      unpublishing_worker
        .expects(:perform)
        .with(unpublished_edition.unpublishing.id, false)
        .in_sequence(unpublish_then_send_draft)

      # 2. Push HTML attachments
      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(unpublished_edition, "republish")
        .in_sequence(unpublish_then_send_draft)

      # 3. Push draft edition
      Whitehall::PublishingApi
        .expects(:save_draft)
        .with(draft_edition, "republish", bulk_publishing: false)
        .in_sequence(unpublish_then_send_draft)

      # 4. Push HTML attachments again
      ServiceListeners::PublishingApiHtmlAttachments
        .expects(:process)
        .with(draft_edition, "republish")
        .in_sequence(unpublish_then_send_draft)

      PublishingApiDocumentRepublishingWorker.new.perform(document.id)
    end

    context "when a draft edition is invalid" do
      let(:draft_edition) { build(:draft_edition, change_note: nil, minor_change: false) }

      it "does not republish the draft edition" do
        Whitehall::PublishingApi
        .expects(:patch_links)
        .with(document.latest_edition, bulk_publishing: false)

        PublishingApiUnpublishingWorker
          .expects(:new)
          .returns(unpublishing_worker = mock)

        unpublished_edition = document.editions.unpublished.last

        unpublishing_worker
          .expects(:perform)
          .with(unpublished_edition.unpublishing.id, false)

        ServiceListeners::PublishingApiHtmlAttachments
          .expects(:process)
          .with(unpublished_edition, "republish")

        Whitehall::PublishingApi
          .expects(:save_draft)
          .with(draft_edition, "republish", bulk_publishing: false)
          .never

        ServiceListeners::PublishingApiHtmlAttachments
          .expects(:process)
          .with(draft_edition, "republish")
          .never

        PublishingApiDocumentRepublishingWorker.new.perform(document.id)
      end
    end
  end

  it "pushes all locales for the published document" do
    document = create(:document)
    edition = build(:published_edition, title: "Published edition", document:)
    with_locale(:es) { edition.title = "spanish-title" }
    edition.save!

    presenter = PublishingApiPresenters.presenter_for(edition, update_type: "republish")
    requests = [
      stub_publishing_api_put_content(document.content_id, with_locale(:en) { presenter.content }),
      stub_publishing_api_publish(document.content_id, locale: "en", update_type: nil),
      stub_publishing_api_put_content(document.content_id, with_locale(:es) { presenter.content }),
      stub_publishing_api_publish(document.content_id, locale: "es", update_type: nil),
      stub_publishing_api_patch_links(document.content_id, links: presenter.links),
    ]

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)

    assert_all_requested(requests)
  end

  it "should ignore old superseded editions when doing bulk republishing" do
    document = create(:document, editions: [build(:superseded_edition)])

    Whitehall::PublishingApi.expects(:publish).never
    Whitehall::PublishingApi.expects(:save_draft).never
    Whitehall::PublishingApi.expects(:locales_for).never
    Whitehall::PublishingApi.expects(:patch_links).never
    PublishingApiUnpublishingWorker.any_instance.expects(:perform).never
    ServiceListeners::PublishingApiHtmlAttachments.expects(:process).never

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)
  end
end

class PublishingApiDocumentRepublishingWorkerHTTPTest < ActiveSupport::TestCase
  test "unpublishes the document, then pushes the new draft" do
    document = create(:document)
    live_edition = create(:unpublished_publication, document:)
    draft_edition = live_edition.create_draft(build(:user))
    draft_edition.change_note = "change-note"
    draft_edition.save!

    presenter = PublishingApiPresenters.presenter_for(live_edition, update_type: "republish")
    draft_presenter = PublishingApiPresenters.presenter_for(draft_edition, update_type: "republish")
    attachment_presenter = PublishingApiPresenters.presenter_for(live_edition.attachments.first, update_type: "republish")
    draft_attachment_presenter = PublishingApiPresenters.presenter_for(draft_edition.attachments.first, update_type: "republish")

    WebMock.reset!

    expected_requests = [
      stub_publishing_api_unpublish(presenter.content_id, body: {
        type: "gone",
        locale: "en",
        discard_drafts: true,
      }),
      stub_publishing_api_put_content(attachment_presenter.content_id, attachment_presenter.content),
      stub_publishing_api_patch_links(attachment_presenter.content_id, links: attachment_presenter.links),
      stub_publishing_api_publish(attachment_presenter.content_id, locale: presenter.content[:locale], update_type: nil),
      stub_publishing_api_unpublish(attachment_presenter.content_id, body: {
        type: "redirect",
        alternative_path: live_edition.base_path,
        discard_drafts: true,
        locale: "en",
      }),
      stub_publishing_api_put_content(draft_presenter.content_id, draft_presenter.content),
      stub_publishing_api_put_content(draft_attachment_presenter.content_id, draft_attachment_presenter.content),
    ]

    PublishingApiDocumentRepublishingWorker.new.perform(document.id)

    assert_all_requested(expected_requests)
  end
end
