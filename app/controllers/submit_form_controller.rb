# frozen_string_literal: true

class SubmitFormController < ApplicationController
  layout 'form'

  skip_before_action :authenticate_user!

  def show
    @submitter =
      Submitter.preload(submission: { template: { documents_attachments: { preview_images_attachments: :blob } } })
               .find_by!(slug: params[:slug])

    cookies.signed[:submitter_sid] = @submitter.signed_id

    redirect_to submit_form_completed_path(@submitter.slug) if @submitter.completed_at?
  end

  def update
    submitter = Submitter.find_by!(slug: params[:slug])
    submitter.values.merge!(normalized_values)
    submitter.completed_at = Time.current if params[:completed] == 'true'
    submitter.opened_at ||= Time.current

    submitter.save!

    if submitter.completed_at?
      submitter.submission.template.account.users.active.each do |user|
        SubmitterMailer.completed_email(submitter, user).deliver_later!
      end
    end

    head :ok
  end

  def completed
    @submitter = Submitter.find_by!(slug: params[:submit_form_slug])
  end

  private

  def normalized_values
    params[:values].to_unsafe_h.transform_values do |v|
      if params[:cast_boolean] == 'true'
        v == 'true'
      else
        v.is_a?(Array) ? v.compact_blank : v
      end
    end
  end
end
