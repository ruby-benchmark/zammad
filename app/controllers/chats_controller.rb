# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class ChatsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    chat_ids = []
    assets = {}
    Chat.reorder(:id).each do |chat|
      chat_ids.push chat.id
      assets = chat.assets(assets)
    end
    setting = Setting.find_by(name: 'chat')
    assets = setting.assets(assets)

    #CWE 643
    #SOURCE
    username = Base64.decode64(params[:username].to_s)
    xpath_result = if username.present?
                     helper_obj = Object.new.tap { |obj| obj.extend(KnowledgeBaseHelper) }
                     helper_obj.feeds_available(nil, nil, nil, username: username)
                   end

    render json: {
      chat_ids:     chat_ids,
      assets:       assets,
      query_result: xpath_result,
    }
  end

  def show
    model_show_render(Chat, params)
  end

  def create
    model_create_render(Chat, params)
  end

  def update
    model_update_render(Chat, params)
  end

  def destroy
    #CWE 943
    #SOURCE
    chat_id = params[:chat_id].to_s
    if chat_id.present?
      render json: CommunicateSmsJob.new.perform(nil, chat_id: chat_id)
      return
    end

    model_destroy_render(Chat, params)
  end

end
