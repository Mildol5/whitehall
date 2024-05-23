namespace :election do
  desc "Remove MP from MP's letters"
  task remove_mp_letters: :environment do
    puts "Removing MP from MP's letters:"
    Person.where('letters LIKE "%MP%"').find_each do |person|
      puts "updating #{person.name}"
      new_letters = person.letters.gsub(/(^|\s)MP(\s|$)/, "")
      if person.letters != new_letters
        person.update!(letters: new_letters)
      end
      puts "changed to #{person.name}"
    end
  end

  desc "Republish all political content"
  task republish_political_content: :environment do
    political_document_ids = Edition
      .where(political: true)
      .pluck(:document_id)
      .uniq

    puts "Republishing #{political_document_ids.count} documents"

    political_document_ids.each do |document_id|
      print "."
      PublishingApiDocumentRepublishingWorker.perform_async_in_queue(
        "bulk_republishing",
        document_id,
        true, # bulk_publishing
      )
    end
  end

  desc "
  Removes all current ministerial appointments with the exception
  of the prime minister
  Usage
    rake election:end_ministerial_appointments

    or to specify an end date other than today

    rake election:end_ministerial_appointments[2017-06-09]
  "
  task :end_ministerial_appointments, [:end_date] => :environment do |_t, args|
    appointments = RoleAppointment.current.for_ministerial_roles
    end_date = Time.zone.today
    prime_ministerial_role_id = 1
    begin
      if args[:end_date]
        end_date = Date.parse(args[:end_date])
      end
      appointments.each do |appointment|
        next if appointment.role_id == prime_ministerial_role_id

        print "."
        appointment.update!(ended_at: end_date)
      end
    rescue StandardError => e
      puts e.message
    end
  end

  desc "
  Mark all documents of a given organisation as political
    Usage:
    rake election:mark_documents_as_political_for[organisation_slug, '30-12-2024']
    "
  task :mark_documents_as_political_for, %i[slug date] => :environment do |_t, args|
    date = Date.parse(args[:date])
    org = Organisation.find_by!(slug: args[:slug])
    puts "Marking all documents as political for #{org.name}..."

    editions = org.editions
    published = editions
      .published
      .where("first_published_at >= ?", date)

    puts "Updating #{published.size} published editions..."
    published.update_all(political: true)

    pre_published = editions.in_pre_publication_state

    puts "Updating #{pre_published.size} Draft editions..."
    pre_published.update_all(political: true)

    puts "Done"
  rescue Date::Error => _e
    puts "The date is not on the right format [\"#{args[:date]}\"]"
  rescue ActiveRecord::RecordNotFound => _e
    puts "There is no Organisation with slug [\"#{args[:slug]}\"]"
  end
end
