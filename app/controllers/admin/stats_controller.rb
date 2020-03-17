class Admin::StatsController < Admin::BaseController
  def show
    @event_types = Ahoy::Event.pluck(:name).uniq.sort

    @visits    = Visit.count
    @debates   = Debate.with_hidden.count
    @proposals = Proposal.with_hidden.count
    @comments  = Comment.not_valuations.with_hidden.count

    @debate_votes   = Vote.where(votable_type: "Debate").count
    @proposal_votes = Vote.where(votable_type: "Proposal").count
    @comment_votes  = Vote.where(votable_type: "Comment").count

    @votes = Vote.count

    @user_level_two   = User.active.level_two_verified.count
    @user_level_three = User.active.level_three_verified.count
    @verified_users   = User.active.level_two_or_three_verified.count
    @unverified_users = User.active.unverified.count
    @users = User.active.count


    @user_ids_who_voted_proposals = ActsAsVotable::Vote.where(votable_type: "Proposal")
                                                       .distinct
                                                       .count(:voter_id)

    @user_ids_who_didnt_vote_proposals = @verified_users - @user_ids_who_voted_proposals
    budgets_ids = Budget.where.not(phase: "finished").pluck(:id)
    @budgets = budgets_ids.size
    @investments = Budget::Investment.where(budget_id: budgets_ids).count


    @total_male_participants = User.active.level_two_or_three_verified.male.count
    @total_female_participants = User.active.level_two_or_three_verified.female.count

    @age_groups = {}
    age_groups.map do |start, finish|
      @age_groups[range_description(start, finish)] = User.active.level_two_or_three_verified.between_ages(start,finish).count
    end

    @geozones = Geozone.all.order("name")
    @verified_users_in_geozone = {}
    @geozones.each do |geozone|
      @verified_users_in_geozone[geozone] = verified_users_in_geozone(geozone)
    end

  end

  def graph
    @name = params[:id]
    @event = params[:event]

    if params[:event]
      @count = Ahoy::Event.where(name: params[:event]).count
    else
      @count = params[:count]
    end
  end

  def proposal_notifications
    @proposal_notifications = ProposalNotification.all
    @proposals_with_notifications = @proposal_notifications.select(:proposal_id).distinct.count
  end

  def proposals
    @proposals = Proposal.with_hidden.sort_by_confidence_score
    @total_proposals = Proposal.with_hidden.count
    @total_supports = Proposal.with_hidden.sum(:cached_votes_up)
    
    @geozones = Geozone.all.order("name")
    @total_district_proposals = {}
    @geozones.each do |geozone|
      @total_district_proposals[geozone] = total_district_proposals(geozone)
    end
  end

  def direct_messages
    @direct_messages = DirectMessage.count
    @users_who_have_sent_message = DirectMessage.select(:sender_id).distinct.count
  end

  def budgets
    @budgets = Budget.all
  end

  def budget_supporting
    @budget = Budget.find(params[:budget_id])
    heading_ids = @budget.heading_ids

    votes = Vote.where(votable_type: "Budget::Investment").
            includes(:budget_investment).
            where(budget_investments: { heading_id: heading_ids })

    @vote_count = votes.count
    @user_count = votes.select(:voter_id).distinct.count

    @voters_in_heading = {}
    @budget.headings.each do |heading|
      @voters_in_heading[heading] = voters_in_heading(heading)
    end
  end

  def budget_balloting
    @budget = Budget.find(params[:budget_id])

    authorize! :read_admin_stats, @budget, message: t("admin.stats.budgets.no_data_before_balloting_phase")

    @user_count = @budget.ballots.select { |ballot| ballot.lines.any? }.count

    @vote_count = @budget.lines.count

    @vote_count_by_heading = @budget.lines.group(:heading_id).count.map { |k, v| [Budget::Heading.find(k).name, v] }.sort

    @user_count_by_district = User.where.not(balloted_heading_id: nil).group(:balloted_heading_id).count.map { |k, v| [Budget::Heading.find(k).name, v] }.sort
  end

  def polls
    @polls = ::Poll.current
    @participants = ::Poll::Voter.where(poll: @polls)
  end

  private

    def voters_in_heading(heading)
      Vote.where(votable_type: "Budget::Investment").
      includes(:budget_investment).
      where(budget_investments: { heading_id: heading.id }).
      select("votes.voter_id").distinct.count
    end

    def age_groups
      [[0, 17],
       [18, 35],
       [36, 64],
       [65, 300]
      ]
    end

    def range_description(start, finish)
      if finish > 200
        I18n.t("admin.stats.show.summary.age_more_than", start: start)
      else
        I18n.t("admin.stats.show.summary.age_range", start: start, finish: finish)
      end
    end

    def verified_users_in_geozone(geozone)
      User.active.level_two_or_three_verified.
      where(geozone_id: geozone.id).count
    end

    def total_district_proposals(geozone)
      Proposal.with_hidden.
      where(geozone_id: geozone.id).count
    end
end
