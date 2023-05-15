class Admin::StatisticsAnnouncementPublicationsController < Admin::BaseController
  before_action :find_statistics_announcement
  layout "design_system"

  def index
    if params[:search].present?
      filter
    end
  end

  def connect
    @statistics_announcement.assign_attributes(publication_params)

    if @statistics_announcement.save
      redirect_to [:admin, @statistics_announcement], notice: "Announcement updated successfully"
    else
      filter
      render :index
    end
  end

private

  def filter
    @filter ||= Admin::EditionFilter.new(get_editions, current_user, edition_filter_options)
  end

  def get_editions
    Edition.statistical_publications.with_title_containing(params[:search])
  end

  def params_filters
    params.slice(:type, :state, :organisation, :author, :page, :title, :world_location, :from_date, :to_date, :only_broken_links)
          .permit!
          .to_h
  end

  def params_filters_with_default_state
    params_filters.reverse_merge("state" => "active")
  end

  def edition_filter_options
    filter_options = params_filters_with_default_state
                       .symbolize_keys
                       .merge(
                         include_unpublishing: true,
                         include_link_check_reports: true,
                         include_last_author: true,
                       )

    filter_options.merge(per_page: Admin::EditionFilter::GOVUK_DESIGN_SYSTEM_PER_PAGE)
  end

  def find_statistics_announcement
    @statistics_announcement = StatisticsAnnouncement.friendly.find(params[:statistics_announcement_id])
  end

  def publication_params
    { publication_id: params[:publication_id] }
  end
end
