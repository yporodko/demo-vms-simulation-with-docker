# Component Template

This is a template for creating new infrastructure components following the established pattern.

## Quick Start

1. **Copy this template:**
   ```bash
   cp -r ansible/templates/component-template ansible/templates/my-component
   ```

2. **Rename files and replace placeholders:**
   - Replace `COMPONENT` with your component name (e.g., `postgres`, `nginx`, `asterisk`)
   - Replace `component` with lowercase version
   - Update all template files with your component's specifics

3. **Move files to proper locations:**
   ```bash
   # Move roles
   mv ansible/templates/my-component/roles/* ansible/roles/

   # Move playbooks
   mv ansible/templates/my-component/playbooks/* ansible/playbooks/

   # Move test script
   mv ansible/templates/my-component/test-component.sh ansible/
   chmod +x ansible/test-component.sh
   ```

4. **Update inventory files:**
   - Add component hosts to `ansible/inventory/hosts.yml`
   - Add component test hosts to `ansible/inventory/hosts-docker-test.yml`

5. **Update Docker Compose:**
   - Add component containers to `docker/docker-compose.yml`

6. **Develop and test:**
   ```bash
   # Start Docker containers
   cd docker && docker-compose up -d my-component-primary-test

   # Deploy with Ansible
   cd ../ansible
   ansible-playbook -i inventory/hosts-docker-test.yml playbooks/my-component-primary.yml

   # Run tests
   ./test-my-component.sh docker

   # When ready, deploy to production
   ansible-playbook playbooks/my-component-primary.yml
   ./test-my-component.sh prod
   ```

## Template Files Included

- `roles/component-primary/` - Primary role template
- `roles/component-replica/` - Replica role template (if needed)
- `playbooks/component-primary.yml` - Primary playbook template
- `playbooks/component-replica.yml` - Replica playbook template
- `playbooks/component.yml` - Master playbook template
- `test-component.sh` - Test script template

## What to Customize

1. **Role tasks** - Define what to install and configure
2. **Templates** - Configuration files specific to your component
3. **Defaults** - Default variables for your component
4. **Handlers** - Service restart handlers
5. **Tests** - Component-specific verification tests
6. **Documentation** - Update this README with component details

See `INFRASTRUCTURE_PATTERN.md` for detailed guidance.
