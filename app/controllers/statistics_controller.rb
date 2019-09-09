class StatisticsController < DocumentsController
  enable_request_formats index: %i[json atom]
  before_action :inject_statistics_publication_filter_option_param, only: :index
  before_action :expire_cache_when_next_publication_published

  def index
    return redirect_formats_to_finder_frontend if Locale.current.english?

    @filter = build_document_filter
    @filter.publications_search

    respond_to do |format|
      format.html do
        @content_item = Whitehall
          .content_store
          .content_item("/government/statistics")
          .to_hash

        @filter = StatisticsFilterJsonPresenter.new(
          @filter, view_context, PublicationesquePresenter
        )
      end
      format.json do
        render json: StatisticsFilterJsonPresenter.new(@filter, view_context, PublicationesquePresenter)
      end
      format.atom do
        documents = Publicationesque.published_with_eager_loading(@filter.documents.map(&:id))
        @statistics = Whitehall::Decorators::CollectionDecorator.new(
          documents.sort_by(&:public_timestamp).reverse,
          PublicationesquePresenter,
          view_context,
        )
      end
    end
  end

private

  def redirect_formats_to_finder_frontend
    respond_to do |format|
      format.html do
        return redirect_to_research_and_statistics
      end
      format.json do
        redirect_to_research_and_statistics(".json")
      end
      format.atom do
        return redirect_to_research_and_statistics(".atom")
      end
    end
  end

  def redirect_to_research_and_statistics(format = "")
    base_path = "#{Plek.new.website_root}/search/research-and-statistics#{format}"
    redirect_to("#{base_path}?#{research_and_statistics_query_string}")
  end

  def research_and_statistics_query_string
    {
      content_store_document_type: 'published_statistics',
      keywords: params['keywords'],
      level_one_taxon: params['taxons'].try(:first),
      organisations: filter_query_array(params['departments']),
      public_timestamp: {
        from: params['from_date'],
        to: params['to_date']
      }.compact.presence,
    }.compact.to_query
  end

  def inject_statistics_publication_filter_option_param
    params[:publication_filter_option] = "statistics"
  end

  def expire_cache_when_next_publication_published
    expire_on_next_scheduled_publication(Publicationesque.scheduled.order("scheduled_publication asc"))
  end
end
