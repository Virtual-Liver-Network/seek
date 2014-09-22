module Seek
  module ProjectHierarchies
    module AdminDefinedRolesExtension
      def self.included mod
        mod.module_eval do
          def add_roles_with_hierarchy roles
            project_ids_before_add = self.admin_defined_role_projects.map(&:project_id)
            #add roles to person's direct projects
            add_roles_without_hierarchy(roles)
            roles_added = self.admin_defined_role_projects.select { |role| !project_ids_before_add.include?(role.project_id) }
            #add roles to sub-projects
            roles_added.each do |role|
              role.project.descendants.each do |sub_proj|
                self.admin_defined_role_projects << self.admin_defined_role_projects.where(project_id: sub_proj.id, role_mask: role.role_mask).first_or_initialize
              end
            end
          end

          def remove_roles_with_hierarchy roles
            roles_before_remove = self.admin_defined_role_projects.map { |role| [role.project_id, role.role_mask] }
            remove_roles_without_hierarchy(roles)
            roles_removed = roles_before_remove.select { |role| self.admin_defined_role_projects.where(project_id: role[0], role_mask: role[1]).empty? }
            #remove roles to sub-projects
            roles_removed.each do |role|
              Project.where(id: role[0]).first.descendants.each do |sub_proj|
                self.admin_defined_role_projects.where(project_id: sub_proj.id, role_mask: role[1]).first.destroy
              end
            end
          end

          alias_method_chain :add_roles, :hierarchy
          alias_method_chain :remove_roles, :hierarchy
        end
      end
    end
  end
end
