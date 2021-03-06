#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

def init
  get_routes
  sections :header, [:method_signature, T('docstring')]
end

def header
  get_routes
  @subtopic = (object.tag('subtopic') || object.parent.tag('API')).text
  route = @routes.first
  @method_link = "method.#{route.requirements[:controller]}.#{route.requirements[:action]}"
  erb(:header)
end

def get_routes
  @controller = object.parent.path.underscore.sub("_controller", '')
  @action = object.path.sub(/^.*#/, '')
  @routes = ApiRouteSet.apis.first.api_methods_for_controller_and_action(@controller, @action)
end
