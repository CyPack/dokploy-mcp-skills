#!/bin/bash
# Development Environment Manager for Fedora 43
# Usage: dev <command> [args]

DEV_DIR="$HOME/dev"
PROJECTS_DIR="$DEV_DIR/projects"
DOKPLOY_APPS_DIR="$DEV_DIR/dokploy-apps"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

# Show all running containers
cmd_status() {
    print_header "🐳 Docker Container Status"
    echo ""
    echo -e "${YELLOW}── Dokploy Services ──${NC}"
    docker service ls 2>/dev/null || echo "No swarm services"
    echo ""
    echo -e "${YELLOW}── All Running Containers ──${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${YELLOW}── Resource Usage ──${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -15
}

# Start a development project
cmd_start() {
    local project=$1
    if [[ -z "$project" ]]; then
        echo -e "${RED}Error: Project name required${NC}"
        echo "Usage: dev start <project-name>"
        return 1
    fi
    
    local project_dir="$PROJECTS_DIR/$project"
    if [[ ! -d "$project_dir" ]]; then
        echo -e "${RED}Error: Project '$project' not found in $PROJECTS_DIR${NC}"
        return 1
    fi
    
    cd "$project_dir"
    if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
        echo -e "${GREEN}Starting $project...${NC}"
        docker compose up -d
    else
        echo -e "${RED}Error: No docker-compose.yml found in $project_dir${NC}"
    fi
}

# Stop a development project
cmd_stop() {
    local project=$1
    if [[ -z "$project" ]]; then
        echo -e "${YELLOW}Stopping all development projects...${NC}"
        for dir in "$PROJECTS_DIR"/*/; do
            if [[ -f "$dir/docker-compose.yml" ]] || [[ -f "$dir/compose.yml" ]]; then
                echo "Stopping $(basename "$dir")..."
                (cd "$dir" && docker compose down)
            fi
        done
    else
        local project_dir="$PROJECTS_DIR/$project"
        if [[ -d "$project_dir" ]]; then
            cd "$project_dir"
            echo -e "${GREEN}Stopping $project...${NC}"
            docker compose down
        else
            echo -e "${RED}Error: Project '$project' not found${NC}"
        fi
    fi
}

# Show logs for a project
cmd_logs() {
    local project=$1
    local project_dir="$PROJECTS_DIR/$project"
    
    if [[ -z "$project" ]]; then
        echo -e "${RED}Error: Project name required${NC}"
        echo "Usage: dev logs <project-name>"
        return 1
    fi
    
    if [[ -d "$project_dir" ]]; then
        cd "$project_dir"
        docker compose logs -f
    else
        echo -e "${RED}Error: Project '$project' not found${NC}"
    fi
}

# List all projects
cmd_list() {
    print_header "📁 Development Projects"
    echo ""
    echo -e "${YELLOW}── Projects (~/dev/projects) ──${NC}"
    if [[ -d "$PROJECTS_DIR" ]] && [[ "$(ls -A $PROJECTS_DIR 2>/dev/null)" ]]; then
        for dir in "$PROJECTS_DIR"/*/; do
            if [[ -d "$dir" ]]; then
                local name=$(basename "$dir")
                local status="⚪ stopped"
                local compose_file=""
                [[ -f "$dir/docker-compose.yml" ]] && compose_file="$dir/docker-compose.yml"
                [[ -f "$dir/compose.yml" ]] && compose_file="$dir/compose.yml"
                
                if [[ -n "$compose_file" ]]; then
                    if docker compose -f "$compose_file" ps -q 2>/dev/null | grep -q .; then
                        status="🟢 running"
                    fi
                fi
                echo "  $status  $name"
            fi
        done
    else
        echo "  (empty)"
    fi
    echo ""
    echo -e "${YELLOW}── Dokploy Apps (~/dev/dokploy-apps) ──${NC}"
    if [[ -d "$DOKPLOY_APPS_DIR" ]] && [[ "$(ls -A $DOKPLOY_APPS_DIR 2>/dev/null)" ]]; then
        ls -1 "$DOKPLOY_APPS_DIR"
    else
        echo "  (empty)"
    fi
}

# Open Dokploy dashboard
cmd_dokploy() {
    echo -e "${GREEN}Opening Dokploy Dashboard...${NC}"
    xdg-open "http://localhost:3000" 2>/dev/null || echo "Open http://localhost:3000 in your browser"
}

# Create new project from template
cmd_new() {
    local project=$1
    local template=${2:-"basic"}
    
    if [[ -z "$project" ]]; then
        echo -e "${RED}Error: Project name required${NC}"
        echo "Usage: dev new <project-name> [template]"
        echo "Templates: basic, node, python, n8n"
        return 1
    fi
    
    local project_dir="$PROJECTS_DIR/$project"
    mkdir -p "$project_dir"
    
    case $template in
        basic)
            cat > "$project_dir/docker-compose.yml" << 'EOF'
services:
  app:
    image: alpine
    command: tail -f /dev/null
    volumes:
      - ./:/app:Z
    working_dir: /app
EOF
            ;;
        node)
            cat > "$project_dir/docker-compose.yml" << 'EOF'
services:
  app:
    image: node:20-alpine
    ports:
      - "${PORT:-4000}:3000"
    volumes:
      - ./:/app:Z
    working_dir: /app
    environment:
      - NODE_ENV=development
    command: sh -c "npm install && npm run dev"
EOF
            echo "PORT=4000" > "$project_dir/.env"
            ;;
        python)
            cat > "$project_dir/docker-compose.yml" << 'EOF'
services:
  app:
    image: python:3.12-slim
    ports:
      - "${PORT:-4100}:8000"
    volumes:
      - ./:/app:Z
    working_dir: /app
    command: sh -c "pip install -r requirements.txt 2>/dev/null; python main.py"
EOF
            echo "PORT=4100" > "$project_dir/.env"
            echo "# requirements.txt" > "$project_dir/requirements.txt"
            echo 'print("Hello from Python!")' > "$project_dir/main.py"
            ;;
        n8n)
            cat > "$project_dir/docker-compose.yml" << 'EOF'
services:
  n8n:
    image: n8nio/n8n:latest
    ports:
      - "${PORT:-4200}:5678"
    volumes:
      - n8n_data:/home/node/.n8n:Z
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=admin
      - GENERIC_TIMEZONE=Europe/Amsterdam
volumes:
  n8n_data:
EOF
            echo "PORT=4200" > "$project_dir/.env"
            ;;
        *)
            echo -e "${RED}Unknown template: $template${NC}"
            echo "Available: basic, node, python, n8n"
            return 1
            ;;
    esac
    
    echo -e "${GREEN}Created project '$project' with '$template' template${NC}"
    echo "Location: $project_dir"
    echo ""
    echo "Next steps:"
    echo "  cd $project_dir"
    echo "  dev start $project"
}

# Show port usage
cmd_ports() {
    print_header "🔌 Port Usage"
    echo ""
    echo -e "${YELLOW}── Reserved Ports ──${NC}"
    echo "  3000   - Dokploy Dashboard"
    echo "  80     - Traefik HTTP"
    echo "  443    - Traefik HTTPS"
    echo "  13000  - NocoBase"
    echo "  13001  - Twenty CRM"
    echo ""
    echo -e "${YELLOW}── Development Range ──${NC}"
    echo "  4000-4999 - Available for dev projects"
    echo ""
    echo -e "${YELLOW}── Currently Listening ──${NC}"
    ss -tulnp 2>/dev/null | grep -E "LISTEN" | awk '{print "  " $1 " " $5}' | sort -t: -k2 -n | uniq
}

# Quick health check
cmd_health() {
    print_header "🏥 Health Check"
    echo ""
    
    # Dokploy
    echo -n "Dokploy (3000): "
    curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
    
    # NocoBase
    echo -n "NocoBase (13000): "
    curl -s -o /dev/null -w "%{http_code}" http://localhost:13000 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
    
    # Twenty
    echo -n "Twenty CRM (13001): "
    curl -s -o /dev/null -w "%{http_code}" http://localhost:13001 2>/dev/null && echo -e " ${GREEN}✓${NC}" || echo -e " ${RED}✗${NC}"
    
    echo ""
}

# Help
cmd_help() {
    print_header "🛠️  Development Manager"
    echo ""
    echo "Usage: dev <command> [args]"
    echo ""
    echo -e "${CYAN}Container Commands:${NC}"
    echo "  status          Show all container status and resources"
    echo "  health          Quick health check of all services"
    echo "  ports           Show port usage"
    echo ""
    echo -e "${CYAN}Project Commands:${NC}"
    echo "  list            List all projects"
    echo "  new <n> [t]     Create new project (templates: basic, node, python, n8n)"
    echo "  start <name>    Start a project"
    echo "  stop [name]     Stop project (or all if no name)"
    echo "  logs <name>     Follow project logs"
    echo ""
    echo -e "${CYAN}Quick Access:${NC}"
    echo "  dokploy         Open Dokploy dashboard"
    echo "  help            Show this help"
    echo ""
}

# Main
case "${1:-help}" in
    status) cmd_status ;;
    health) cmd_health ;;
    list|ls) cmd_list ;;
    start) cmd_start "$2" ;;
    stop) cmd_stop "$2" ;;
    logs) cmd_logs "$2" ;;
    new) cmd_new "$2" "$3" ;;
    ports) cmd_ports ;;
    dokploy) cmd_dokploy ;;
    help|--help|-h) cmd_help ;;
    *) echo "Unknown command: $1"; cmd_help ;;
esac
