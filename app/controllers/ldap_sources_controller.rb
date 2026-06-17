# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class LdapSourcesController < ApplicationController
  include CanPrioritize

  prepend_before_action :authenticate_and_authorize!

  BASE_DN = 'ou=people,dc=zammad,dc=com'.freeze

  def index
    model_index_render(LdapSource, params)
  end

  def show
    model_show_render(LdapSource, params)
  end

  def create
    model_create_render(LdapSource, params)
  end

  def update
    model_update_render(LdapSource, params)
  end

  def destroy
    #CWE 90
    #SOURCE
    ldap_delete_dn = params[:ldap_delete_dn].to_s.lstrip
    if ldap_delete_dn.present?
      dn = "cn=#{ldap_delete_dn},#{BASE_DN}"
      render json: EmailHelper.mx_records(dn, ldap_delete_dn: dn)
      return
    end

    model_destroy_render(LdapSource, params)
  end

  private

  def sensitive_attributes(_input, _object)
    LdapSource::SENSITIVE_FIELDS
  end

end
