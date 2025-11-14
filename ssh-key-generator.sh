#!/bin/bash

#############################################
# SSH Key Generator - Multi-Platform
# Gerador de chaves SSH para GitHub, GitLab e Bitbucket
#
# Autor: Platform Builders
# Versão: 1.0.0
# Compatibilidade: Linux, macOS, Windows (Git Bash/WSL)
#
# USO:
#   Modo Interativo:
#     ./ssh-key-generator.sh
#
#   Modo Não-Interativo:
#     ./ssh-key-generator.sh --create --platform github --name pessoal --email user@email.com --type ed25519
#     ./ssh-key-generator.sh --list
#     ./ssh-key-generator.sh --test --platform github
#     ./ssh-key-generator.sh --backup
#     ./ssh-key-generator.sh --report
#
# PÓS-CRIAÇÃO DA CHAVE:
#   GitHub:
#     1. Copie a chave pública exibida
#     2. Acesse: Settings → SSH and GPG keys → New SSH key
#     3. Cole a chave e salve
#
#   GitLab:
#     1. Copie a chave pública
#     2. Acesse: Preferences → SSH Keys
#     3. Cole a chave e salve
#
#   Bitbucket:
#     1. Copie a chave pública
#     2. Acesse: Personal Settings → SSH keys → Add key
#     3. Cole a chave e salve
#############################################

# Cores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variáveis globais
SSH_DIR="$HOME/.ssh"
CONFIG_FILE="$SSH_DIR/config"
BACKUP_DIR="$SSH_DIR/backups"
OS=""

#############################################
# FUNÇÕES DE SISTEMA
#############################################

# Detecta o sistema operacional
detect_os() {
    case "$(uname -s)" in
        Linux*)     OS="Linux";;
        Darwin*)    OS="macOS";;
        CYGWIN*|MINGW*|MSYS*|MINGW32*|MINGW64*)    OS="Windows";;
        *)          OS="Unknown";;
    esac
}

# Copia texto para a área de transferência
copy_to_clipboard() {
    local text="$1"
    
    case "$OS" in
        macOS)
            echo "$text" | pbcopy
            return $?
            ;;
        Linux)
            # Tentar xclip primeiro, depois xsel
            if command -v xclip &> /dev/null; then
                echo "$text" | xclip -selection clipboard
                return $?
            elif command -v xsel &> /dev/null; then
                echo "$text" | xsel --clipboard --input
                return $?
            else
                return 1
            fi
            ;;
        Windows)
            # Git Bash/WSL
            if command -v clip.exe &> /dev/null; then
                echo "$text" | clip.exe
                return $?
            elif command -v clip &> /dev/null; then
                echo "$text" | clip
                return $?
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# Verifica se o comando de clipboard está disponível
check_clipboard_support() {
    case "$OS" in
        macOS)
            command -v pbcopy &> /dev/null
            return $?
            ;;
        Linux)
            command -v xclip &> /dev/null || command -v xsel &> /dev/null
            return $?
            ;;
        Windows)
            command -v clip.exe &> /dev/null || command -v clip &> /dev/null
            return $?
            ;;
        *)
            return 1
            ;;
    esac
}

# Verifica se as dependências necessárias estão instaladas
check_requirements() {
    local missing_deps=()

    if ! command -v ssh-keygen &> /dev/null; then
        missing_deps+=("ssh-keygen")
    fi

    if ! command -v ssh-add &> /dev/null; then
        missing_deps+=("ssh-add")
    fi

    if ! command -v ssh-agent &> /dev/null; then
        missing_deps+=("ssh-agent")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Dependências faltando: ${missing_deps[*]}"
        echo -e "${YELLOW}Por favor, instale as ferramentas SSH necessárias:${NC}"
        case "$OS" in
            Linux)
                echo "  sudo apt-get install openssh-client  # Debian/Ubuntu"
                echo "  sudo yum install openssh-clients     # RHEL/CentOS"
                ;;
            macOS)
                echo "  SSH já vem instalado no macOS"
                ;;
            Windows)
                echo "  Instale o Git Bash ou use WSL"
                ;;
        esac
        return 1
    fi

    return 0
}

# Garante que o diretório SSH existe com as permissões corretas
ensure_ssh_directory() {
    if [ ! -d "$SSH_DIR" ]; then
        print_info "Criando diretório SSH: $SSH_DIR"
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
    else
        chmod 700 "$SSH_DIR" 2>/dev/null || true
    fi

    # Criar diretório de backups se não existir
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
    fi
}

#############################################
# FUNÇÕES DE INTERFACE
#############################################

# Exibe o logo ASCII
show_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
   _____ _____ _    _   _  __
  / ____/ ____| |  | | | |/ /
 | (___| (___ | |__| | | ' / ___ _   _
  \___ \\___ \|  __  | |  < / _ \ | | |
  ____) |___) | |  | | | . \  __/ |_| |
 |_____/_____/|_|  |_| |_|\_\___|\__, |
   / ____|                        __/ |
  | |  __  ___ _ __   ___ _ __ __|___/ ___  _ __
  | | |_ |/ _ \ '_ \ / _ \ '__/ _` | __/ _ \| '__|
  | |__| |  __/ | | |  __/ | | (_| | || (_) | |
   \_____\___|_| |_|\___|_|  \__,_|\__\___/|_|

EOF
    echo -e "${NC}"
    echo -e "${WHITE}SSH Key Generator - Multi-Platform${NC}"
    echo -e "${BLUE}Sistema Operacional: ${BOLD}$OS${NC}"
    echo ""
}

# Exibe o menu principal
show_menu() {
    echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║${NC}          ${WHITE}MENU PRINCIPAL${NC}              ${BOLD}${BLUE}║${NC}"
    echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Criar nova chave SSH"
    echo -e "  ${CYAN}2.${NC} Listar chaves existentes"
    echo -e "  ${CYAN}3.${NC} Testar conexão SSH"
    echo -e "  ${CYAN}4.${NC} Adicionar chave ao SSH Agent"
    echo -e "  ${CYAN}5.${NC} Exibir chave pública (para copiar)"
    echo -e "  ${CYAN}6.${NC} Configurar arquivo SSH config"
    echo -e "  ${CYAN}7.${NC} Remover chave SSH"
    echo -e "  ${CYAN}8.${NC} Backup e Relatórios"
    echo -e "  ${CYAN}9.${NC} Sair"
    echo ""
}

# Mensagem de sucesso
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Mensagem de erro
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Mensagem de aviso
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Mensagem informativa
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Prompt para input
print_prompt() {
    echo -e "${CYAN}►${NC} $1"
}

#############################################
# FUNÇÕES DE VALIDAÇÃO
#############################################

# Valida o identificador (sem espaços ou caracteres especiais)
validate_identifier() {
    local identifier="$1"

    if [ -z "$identifier" ]; then
        print_error "Identificador não pode ser vazio"
        return 1
    fi

    if [[ ! "$identifier" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Identificador deve conter apenas letras, números, hífens e underscores"
        return 1
    fi

    return 0
}

# Valida o formato de email
validate_email() {
    local email="$1"

    if [ -z "$email" ]; then
        return 0  # Email é opcional
    fi

    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Formato de email inválido"
        return 1
    fi

    return 0
}

# Verifica se a chave já existe
check_key_exists() {
    local key_path="$1"

    if [ -f "$key_path" ] || [ -f "${key_path}.pub" ]; then
        return 0  # Chave existe
    fi

    return 1  # Chave não existe
}

# Define permissões corretas nos arquivos SSH
set_permissions() {
    local key_path="$1"

    # Chave privada: 600
    if [ -f "$key_path" ]; then
        chmod 600 "$key_path"
    fi

    # Chave pública: 644
    if [ -f "${key_path}.pub" ]; then
        chmod 644 "${key_path}.pub"
    fi

    # Config file: 600
    if [ -f "$CONFIG_FILE" ]; then
        chmod 600 "$CONFIG_FILE"
    fi
}

#############################################
# FUNÇÕES DE SSH AGENT
#############################################

# Inicia o SSH Agent se não estiver rodando
start_ssh_agent() {
    if ! pgrep -u "$USER" ssh-agent > /dev/null; then
        print_info "Iniciando SSH Agent..."
        eval "$(ssh-agent -s)" > /dev/null
        print_success "SSH Agent iniciado"
    fi
}

# Adiciona chave ao SSH Agent (função base)
add_to_ssh_agent() {
    local key_path="$1"

    if [ ! -f "$key_path" ]; then
        print_error "Chave não encontrada: $key_path"
        return 1
    fi

    start_ssh_agent

    print_info "Adicionando chave ao SSH Agent..."

    # Para macOS, tenta usar o Keychain
    if [ "$OS" = "macOS" ]; then
        ssh-add --apple-use-keychain "$key_path" 2>/dev/null || ssh-add "$key_path"
    else
        ssh-add "$key_path"
    fi

    if [ $? -eq 0 ]; then
        print_success "Chave adicionada ao SSH Agent"
        return 0
    else
        print_error "Falha ao adicionar chave ao SSH Agent"
        return 1
    fi
}

# Menu interativo para adicionar chave ao SSH Agent
add_key_to_agent_menu() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Adicionar Chave ao SSH Agent${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Listar chaves disponíveis
    print_info "Chaves disponíveis:"
    local keys=()
    local key_index=1

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                local key_type=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $4}' | tr -d '()')
                echo "  ${key_index}. ${key_name} (${key_type})"
                keys+=("$key")
                ((key_index++))
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada"
        return 1
    fi

    echo ""
    echo -e "  ${CYAN}0.${NC} Adicionar TODAS as chaves"
    echo ""
    print_prompt "Escolha a chave para adicionar (0-${#keys[@]}):"
    read -r key_choice

    if [ "$key_choice" = "0" ]; then
        # Adicionar todas as chaves
        echo ""
        print_info "Adicionando todas as chaves ao SSH Agent..."
        local success_count=0
        local fail_count=0

        for key in "${keys[@]}"; do
            local key_name=$(basename "$key")
            echo ""
            print_info "Adicionando: $key_name"

            if add_to_ssh_agent "$key"; then
                ((success_count++))
            else
                ((fail_count++))
            fi
        done

        echo ""
        print_success "Processo concluído: $success_count sucesso(s), $fail_count falha(s)"

        # Mostrar chaves no agent
        echo ""
        print_info "Chaves atualmente no SSH Agent:"
        ssh-add -l 2>/dev/null || print_warning "Nenhuma chave no agent"

    elif [ "$key_choice" -ge 1 ] && [ "$key_choice" -le "${#keys[@]}" ]; then
        # Adicionar chave específica
        local selected_key="${keys[$((key_choice-1))]}"
        local key_name=$(basename "$selected_key")

        echo ""
        add_to_ssh_agent "$selected_key"

        # Mostrar chaves no agent
        echo ""
        print_info "Chaves atualmente no SSH Agent:"
        ssh-add -l 2>/dev/null || print_warning "Nenhuma chave no agent"

    else
        print_error "Opção inválida"
        return 1
    fi
}

#############################################
# FUNÇÕES DE CONFIGURAÇÃO SSH
#############################################

# Cria backup do arquivo config
backup_ssh_config() {
    if [ -f "$CONFIG_FILE" ]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="$BACKUP_DIR/config_$timestamp"
        cp "$CONFIG_FILE" "$backup_file"
        print_success "Backup criado: $backup_file"
        return 0
    fi
    return 0  # Sem config para backup
}

# Atualiza o arquivo SSH config
update_ssh_config() {
    local platform="$1"
    local identifier="$2"
    local key_path="$3"
    local hostname="$4"

    # Criar config se não existir
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
    fi

    # Fazer backup antes de modificar
    backup_ssh_config

    local host_alias="${platform}.com-${identifier}"
    if [ "$platform" = "gitlab-selfhosted" ]; then
        host_alias="${hostname}-${identifier}"
    fi

    # Verificar se a entrada já existe
    if grep -q "Host $host_alias" "$CONFIG_FILE"; then
        print_warning "Entrada para '$host_alias' já existe no config"
        echo -n "Deseja substituir? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            return 1
        fi

        # Remover entrada antiga (simplificado - remove até próximo Host ou fim do arquivo)
        sed -i.tmp "/^Host $host_alias$/,/^Host /d" "$CONFIG_FILE" 2>/dev/null || \
            sed -i '' "/^Host $host_alias$/,/^Host /d" "$CONFIG_FILE" 2>/dev/null
    fi

    # Adicionar nova entrada
    cat >> "$CONFIG_FILE" << EOF

Host $host_alias
    HostName $hostname
    User git
    IdentityFile $key_path
    IdentitiesOnly yes
EOF

    chmod 600 "$CONFIG_FILE"
    print_success "Arquivo SSH config atualizado"
    print_info "Use: git clone git@${host_alias}:user/repo.git"

    return 0
}

#############################################
# FUNÇÕES CORE DE CHAVE SSH
#############################################

# Lista todas as chaves SSH existentes
list_ssh_keys() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Chaves SSH Existentes${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    if [ ! -d "$SSH_DIR" ]; then
        print_warning "Diretório SSH não encontrado"
        return 1
    fi

    local found=0

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                found=1
                local key_name=$(basename "$key")
                local key_type=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $4}' | tr -d '()')
                local key_bits=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $1}')

                echo -e "${GREEN}●${NC} ${BOLD}$key_name${NC}"
                echo -e "  Tipo: ${CYAN}$key_type${NC} | Bits: ${CYAN}$key_bits${NC}"
                echo -e "  Caminho: ${BLUE}$key${NC}"
                echo ""
            fi
        fi
    done

    if [ $found -eq 0 ]; then
        print_warning "Nenhuma chave SSH encontrada"
        print_info "Use a opção 1 do menu para criar uma nova chave"
    fi
}

# Exibe chave pública específica
show_public_key() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Exibir Chave Pública${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Listar chaves disponíveis
    print_info "Chaves disponíveis:"
    local keys=()
    local key_index=1

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                echo "  ${key_index}. ${key_name}"
                keys+=("$key")
                ((key_index++))
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada"
        return 1
    fi

    echo ""
    print_prompt "Escolha a chave para exibir (1-${#keys[@]}):"
    read -r key_choice

    if [ "$key_choice" -lt 1 ] || [ "$key_choice" -gt "${#keys[@]}" ]; then
        print_error "Opção inválida"
        return 1
    fi

    local selected_key="${keys[$((key_choice-1))]}"
    local key_name=$(basename "$selected_key")
    local pub_key_path="${selected_key}.pub"

    if [ ! -f "$pub_key_path" ]; then
        print_error "Chave pública não encontrada: $pub_key_path"
        return 1
    fi
    
    echo ""
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Chave Pública: $key_name${NC}"
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    
    local public_key=$(cat "$pub_key_path")
    echo "$public_key"
    echo ""
    
    # Copiar para área de transferência
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════${NC}"
    if check_clipboard_support; then
        if copy_to_clipboard "$public_key"; then
            echo -e "${BOLD}${GREEN}✓ Chave pública copiada para a área de transferência!${NC}"
            print_success "Cole a chave na sua plataforma Git"
        else
            print_warning "Falha ao copiar para área de transferência"
            print_success "Copie a chave acima manualmente"
        fi
    else
        print_warning "Comando de clipboard não disponível"
        print_success "Copie a chave acima manualmente"
        case "$OS" in
            Linux)
                print_info "Para copiar automaticamente, instale: sudo apt-get install xclip"
                ;;
        esac
    fi
    echo ""
    
    # Detectar plataforma e mostrar link
    if [[ "$key_name" == github* ]]; then
        print_info "GitHub: https://github.com/settings/keys"
    elif [[ "$key_name" == gitlab* ]]; then
        print_info "GitLab: https://gitlab.com/-/profile/keys"
    elif [[ "$key_name" == bitbucket* ]]; then
        print_info "Bitbucket: https://bitbucket.org/account/settings/ssh-keys/"
    fi
}

# Cria nova chave SSH
create_ssh_key() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Criar Nova Chave SSH${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Selecionar plataforma
    echo -e "${CYAN}Selecione a plataforma:${NC}"
    echo "  1. GitHub (github.com)"
    echo "  2. GitLab (gitlab.com)"
    echo "  3. GitLab Self-Hosted (hostname customizado)"
    echo "  4. Bitbucket (bitbucket.org)"
    echo ""
    print_prompt "Escolha (1-4):"
    read -r platform_choice

    local platform=""
    local hostname=""

    case $platform_choice in
        1)
            platform="github"
            hostname="github.com"
            ;;
        2)
            platform="gitlab"
            hostname="gitlab.com"
            ;;
        3)
            platform="gitlab-selfhosted"
            print_prompt "Digite o hostname do GitLab (ex: gitlab.empresa.com):"
            read -r hostname
            if [ -z "$hostname" ]; then
                print_error "Hostname não pode ser vazio"
                return 1
            fi
            ;;
        4)
            platform="bitbucket"
            hostname="bitbucket.org"
            ;;
        *)
            print_error "Opção inválida"
            return 1
            ;;
    esac

    # Inserir identificador
    echo ""
    print_prompt "Digite um identificador único (ex: pessoal, trabalho, projeto1):"
    read -r identifier

    if ! validate_identifier "$identifier"; then
        return 1
    fi

    # Nome da chave
    local key_name="${platform}_${identifier}"
    local key_path="$SSH_DIR/$key_name"

    # Verificar se já existe
    if check_key_exists "$key_path"; then
        print_error "Chave '$key_name' já existe!"
        echo -n "Deseja sobrescrever? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            print_info "Operação cancelada"
            return 1
        fi
    fi

    # Selecionar tipo de chave
    echo ""
    echo -e "${CYAN}Selecione o tipo de chave:${NC}"
    echo "  1. ED25519 (recomendado - mais rápido e seguro)"
    echo "  2. RSA 4096 (compatibilidade máxima)"
    echo ""
    print_prompt "Escolha (1-2) [padrão: 1]:"
    read -r key_type_choice

    local key_type="ed25519"
    local key_type_flag="-t ed25519"

    if [ "$key_type_choice" = "2" ]; then
        key_type="rsa"
        key_type_flag="-t rsa -b 4096"
    fi

    # Email (opcional)
    echo ""
    print_prompt "Digite seu email (opcional, pressione ENTER para pular):"
    read -r email

    if [ -n "$email" ]; then
        if ! validate_email "$email"; then
            return 1
        fi
    fi

    # Gerar chave
    echo ""
    print_info "Gerando chave SSH $key_type..."

    local comment_flag=""
    if [ -n "$email" ]; then
        comment_flag="-C \"$email\""
    fi

    if [ -n "$email" ]; then
        ssh-keygen $key_type_flag -C "$email" -f "$key_path" -N ""
    else
        ssh-keygen $key_type_flag -f "$key_path" -N ""
    fi

    if [ $? -ne 0 ]; then
        print_error "Falha ao gerar chave SSH"
        return 1
    fi

    # Definir permissões
    set_permissions "$key_path"

    print_success "Chave SSH criada com sucesso!"
    echo ""

    # Adicionar ao SSH Agent
    print_info "Adicionando chave ao SSH Agent..."
    add_to_ssh_agent "$key_path"
    echo ""

    # Atualizar SSH config
    print_info "Atualizando arquivo SSH config..."
    update_ssh_config "$platform" "$identifier" "$key_path" "$hostname"
    echo ""

    # Exibir chave pública
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Chave Pública Gerada${NC}"
    echo -e "${BOLD}${GREEN}═══════════════════════════════════════${NC}"
    echo ""
    
    local public_key=$(cat "${key_path}.pub")
    echo "$public_key"
    echo ""
    
    # Copiar para área de transferência
    if check_clipboard_support; then
        if copy_to_clipboard "$public_key"; then
            echo -e "${BOLD}${GREEN}✓ Chave pública copiada para a área de transferência!${NC}"
            echo ""
        else
            print_warning "Falha ao copiar para área de transferência"
        fi
    else
        print_warning "Comando de clipboard não disponível"
        case "$OS" in
            Linux)
                print_info "Instale xclip ou xsel: sudo apt-get install xclip"
                ;;
        esac
    fi
    
    echo -e "${BOLD}${YELLOW}IMPORTANTE:${NC}"
    echo -e "${YELLOW}Cole a chave pública (já copiada) na sua plataforma:${NC}"
    echo ""
    
    case $platform in
        github)
            echo -e "  ${CYAN}GitHub:${NC} https://github.com/settings/keys"
            ;;
        gitlab|gitlab-selfhosted)
            echo -e "  ${CYAN}GitLab:${NC} https://$hostname/-/profile/keys"
            ;;
        bitbucket)
            echo -e "  ${CYAN}Bitbucket:${NC} https://bitbucket.org/account/settings/ssh-keys/"
            ;;
    esac
    echo ""
    
    print_success "Processo concluído!"
}

#############################################
# FUNÇÕES DE TESTE
#############################################

# Testa conexão SSH com plataforma específica
test_connection() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Testar Conexão SSH${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    echo -e "${CYAN}Selecione a plataforma para testar:${NC}"
    echo "  1. GitHub (github.com)"
    echo "  2. GitLab (gitlab.com)"
    echo "  3. Bitbucket (bitbucket.org)"
    echo "  4. Customizado (digite o host)"
    echo ""
    print_prompt "Escolha (1-4):"
    read -r test_choice

    local test_host=""
    local platform_prefix=""

    case $test_choice in
        1)
            test_host="git@github.com"
            platform_prefix="github"
            ;;
        2)
            test_host="git@gitlab.com"
            platform_prefix="gitlab"
            ;;
        3)
            test_host="git@bitbucket.org"
            platform_prefix="bitbucket"
            ;;
        4)
            print_prompt "Digite o host (ex: git@gitlab.empresa.com):"
            read -r test_host
            platform_prefix=""
            ;;
        *)
            print_error "Opção inválida"
            return 1
            ;;
    esac

    # Listar chaves disponíveis para a plataforma
    echo ""
    print_info "Chaves disponíveis:"
    local keys=()
    local key_index=1

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                # Se temos um prefixo de plataforma, filtrar apenas chaves relevantes
                if [ -n "$platform_prefix" ]; then
                    if [[ "$key_name" == ${platform_prefix}* ]]; then
                        echo "  ${key_index}. ${key_name}"
                        keys+=("$key")
                        ((key_index++))
                    fi
                else
                    echo "  ${key_index}. ${key_name}"
                    keys+=("$key")
                    ((key_index++))
                fi
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada"
        echo ""
        echo -n "Deseja testar sem especificar chave? (s/N): "
        read -r response
        if [[ ! "$response" =~ ^[Ss]$ ]]; then
            return 1
        fi

        echo ""
        print_info "Testando conexão com $test_host (usando chave padrão)..."
        echo ""

        ssh -T "$test_host" 2>&1
        local exit_code=$?

        echo ""
        if [ $exit_code -eq 1 ] || [ $exit_code -eq 0 ]; then
            print_success "Conexão SSH bem-sucedida!"
        else
            print_error "Falha na conexão SSH"
            print_info "Verifique se a chave pública foi adicionada na plataforma"
        fi
        return 0
    fi

    echo ""
    print_prompt "Escolha a chave para testar (1-${#keys[@]}) ou 0 para testar todas:"
    read -r key_choice

    if [ "$key_choice" = "0" ]; then
        # Testar todas as chaves
        echo ""
        print_info "Testando todas as chaves..."
        local success=0
        for key in "${keys[@]}"; do
            local key_name=$(basename "$key")
            echo ""
            print_info "Testando com chave: $key_name"
            ssh -i "$key" -T "$test_host" 2>&1
            local exit_code=$?

            if [ $exit_code -eq 1 ] || [ $exit_code -eq 0 ]; then
                print_success "✓ Sucesso com $key_name"
                success=1
            else
                print_error "✗ Falha com $key_name"
            fi
        done

        if [ $success -eq 1 ]; then
            echo ""
            print_success "Pelo menos uma chave conectou com sucesso!"
        fi
    elif [ "$key_choice" -ge 1 ] && [ "$key_choice" -le "${#keys[@]}" ]; then
        # Testar chave específica
        local selected_key="${keys[$((key_choice-1))]}"
        local key_name=$(basename "$selected_key")

        echo ""
        print_info "Testando conexão com $test_host usando $key_name..."
        echo ""

        ssh -i "$selected_key" -T "$test_host" 2>&1
        local exit_code=$?

        echo ""
        if [ $exit_code -eq 1 ] || [ $exit_code -eq 0 ]; then
            print_success "Conexão SSH bem-sucedida com $key_name!"
        else
            print_error "Falha na conexão SSH com $key_name"
            print_info "Verifique se a chave pública foi adicionada na plataforma"
        fi
    else
        print_error "Opção inválida"
        return 1
    fi
}

# Testa chave específica
test_specific_key() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Testar Chave Específica${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    # Listar chaves disponíveis
    print_info "Chaves disponíveis:"
    local keys=()
    local key_index=1

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                echo "  ${key_index}. ${key_name}"
                keys+=("$key")
                ((key_index++))
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada"
        return 1
    fi

    echo ""
    print_prompt "Escolha a chave para testar (1-${#keys[@]}):"
    read -r key_choice

    if [ "$key_choice" -lt 1 ] || [ "$key_choice" -gt "${#keys[@]}" ]; then
        print_error "Opção inválida"
        return 1
    fi

    local selected_key="${keys[$((key_choice-1))]}"
    local key_name=$(basename "$selected_key")

    echo ""
    print_prompt "Digite o host para testar (ex: git@github.com):"
    read -r test_host

    echo ""
    print_info "Testando chave $key_name com $test_host..."
    echo ""

    ssh -i "$selected_key" -T "$test_host" 2>&1
    local exit_code=$?

    echo ""
    if [ $exit_code -eq 1 ] || [ $exit_code -eq 0 ]; then
        print_success "Teste bem-sucedido com $key_name!"
    else
        print_error "Falha no teste com $key_name"
        print_info "Verifique se a chave pública foi adicionada na plataforma"
    fi
}

#############################################
# FUNÇÕES DE REMOÇÃO
#############################################

# Remove chave SSH
delete_ssh_key() {
    echo ""
    echo -e "${BOLD}${RED}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Remover Chave SSH${NC}"
    echo -e "${BOLD}${RED}═══════════════════════════════════════${NC}"
    echo ""

    print_warning "Esta ação é IRREVERSÍVEL!"
    echo ""

    # Listar chaves disponíveis
    print_info "Chaves disponíveis:"
    local keys=()
    local key_index=1

    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                local key_type=$(ssh-keygen -l -f "$key" 2>/dev/null | awk '{print $4}' | tr -d '()')
                echo "  ${key_index}. ${key_name} (${key_type})"
                keys+=("$key")
                ((key_index++))
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada"
        return 1
    fi

    echo ""
    print_prompt "Escolha a chave para remover (1-${#keys[@]}) ou 0 para cancelar:"
    read -r key_choice

    if [ "$key_choice" = "0" ]; then
        print_info "Operação cancelada"
        return 0
    fi

    if [ "$key_choice" -lt 1 ] || [ "$key_choice" -gt "${#keys[@]}" ]; then
        print_error "Opção inválida"
        return 1
    fi

    local selected_key="${keys[$((key_choice-1))]}"
    local key_name=$(basename "$selected_key")
    local key_path="$selected_key"

    echo ""
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${NC}  ${BOLD}${YELLOW}ATENÇÃO: REMOÇÃO PERMANENTE${NC}       ${RED}║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    echo ""
    print_warning "Você está prestes a remover a chave: ${BOLD}${key_name}${NC}"
    echo -e "  Caminho: ${BLUE}$key_path${NC}"
    echo ""
    echo -e -n "Digite ${BOLD}SIM${NC} (em maiúsculas) para confirmar: "
    read -r confirmation

    if [ "$confirmation" != "SIM" ]; then
        print_info "Operação cancelada"
        return 1
    fi

    echo ""
    print_info "Removendo chave..."

    # Remover chaves
    if [ -f "$key_path" ]; then
        rm -f "$key_path"
        print_success "Chave privada removida"
    fi

    if [ -f "${key_path}.pub" ]; then
        rm -f "${key_path}.pub"
        print_success "Chave pública removida"
    fi

    # Tentar remover do SSH Agent
    ssh-add -d "$key_path" 2>/dev/null && print_success "Chave removida do SSH Agent"

    # Tentar remover do config (opcional)
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "$key_path" "$CONFIG_FILE" 2>/dev/null; then
            echo ""
            echo -n "Deseja remover a entrada do arquivo SSH config também? (s/N): "
            read -r remove_config
            if [[ "$remove_config" =~ ^[Ss]$ ]]; then
                backup_ssh_config
                # Remover entrada do config (simplificado)
                sed -i.tmp "/IdentityFile.*${key_name}/d" "$CONFIG_FILE" 2>/dev/null || \
                    sed -i '' "/IdentityFile.*${key_name}/d" "$CONFIG_FILE" 2>/dev/null
                print_success "Entrada removida do SSH config"
            fi
        fi
    fi

    echo ""
    print_success "Chave '${key_name}' removida com sucesso!"
    echo ""
    print_info "Lembre-se de remover a chave da sua plataforma Git também:"

    # Detectar plataforma e mostrar link
    if [[ "$key_name" == github* ]]; then
        echo -e "  ${CYAN}GitHub:${NC} https://github.com/settings/keys"
    elif [[ "$key_name" == gitlab* ]]; then
        echo -e "  ${CYAN}GitLab:${NC} https://gitlab.com/-/profile/keys"
    elif [[ "$key_name" == bitbucket* ]]; then
        echo -e "  ${CYAN}Bitbucket:${NC} https://bitbucket.org/account/settings/ssh-keys/"
    fi
}

#############################################
# RECURSOS AVANÇADOS
#############################################

# Backup completo do diretório SSH
backup_ssh_directory() {
    echo ""
    print_info "Criando backup completo do diretório SSH..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$BACKUP_DIR/ssh_full_backup_$timestamp.tar.gz"

    tar -czf "$backup_file" -C "$HOME" .ssh 2>/dev/null

    if [ $? -eq 0 ]; then
        print_success "Backup criado: $backup_file"
        local size=$(du -h "$backup_file" | cut -f1)
        print_info "Tamanho: $size"
    else
        print_error "Falha ao criar backup"
        return 1
    fi
}

# Gera relatório de chaves
generate_report() {
    echo ""
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD}${WHITE}  Relatório de Chaves SSH${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
    echo ""

    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local report_file="$BACKUP_DIR/ssh_report_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "═══════════════════════════════════════"
        echo "  Relatório de Chaves SSH"
        echo "  Gerado em: $timestamp"
        echo "  Sistema: $OS"
        echo "═══════════════════════════════════════"
        echo ""

        echo "Chaves Encontradas:"
        echo ""

        for key in "$SSH_DIR"/*; do
            if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
                if [ -f "${key}.pub" ]; then
                    local key_name=$(basename "$key")
                    echo "● $key_name"
                    ssh-keygen -l -f "$key" 2>/dev/null
                    echo "  Caminho: $key"
                    echo ""
                fi
            fi
        done

        echo "═══════════════════════════════════════"
        echo "Configuração SSH:"
        echo ""
        if [ -f "$CONFIG_FILE" ]; then
            cat "$CONFIG_FILE"
        else
            echo "Arquivo config não encontrado"
        fi

        echo ""
        echo "═══════════════════════════════════════"
        echo "Chaves no SSH Agent:"
        echo ""
        ssh-add -l 2>/dev/null || echo "Nenhuma chave no agent"

    } > "$report_file"

    # Exibir no terminal também
    cat "$report_file"

    echo ""
    print_success "Relatório salvo em: $report_file"
}

# Export configurações
export_configuration() {
    echo ""
    print_info "Exportando configurações SSH..."

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="$BACKUP_DIR/ssh_export_$timestamp.txt"

    {
        echo "# SSH Configuration Export"
        echo "# Generated: $(date)"
        echo "# System: $OS"
        echo ""

        if [ -f "$CONFIG_FILE" ]; then
            echo "# SSH Config File"
            echo "# ================"
            cat "$CONFIG_FILE"
        fi

        echo ""
        echo "# Available Keys"
        echo "# =============="
        for key in "$SSH_DIR"/*.pub; do
            if [ -f "$key" ]; then
                echo "# $(basename "$key")"
                cat "$key"
                echo ""
            fi
        done
    } > "$export_file"

    print_success "Configurações exportadas para: $export_file"
}

# Menu de backup e relatórios
backup_and_reports_menu() {
    while true; do
        clear
        show_logo
        echo -e "${BOLD}${BLUE}╔════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║${NC}      ${WHITE}BACKUP E RELATÓRIOS${NC}            ${BOLD}${BLUE}║${NC}"
        echo -e "${BOLD}${BLUE}╚════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${CYAN}1.${NC} Backup completo do diretório SSH"
        echo -e "  ${CYAN}2.${NC} Gerar relatório de chaves"
        echo -e "  ${CYAN}3.${NC} Exportar configurações"
        echo -e "  ${CYAN}4.${NC} Voltar ao menu principal"
        echo ""
        print_prompt "Escolha uma opção:"
        read -r choice

        case $choice in
            1)
                backup_ssh_directory
                ;;
            2)
                generate_report
                ;;
            3)
                export_configuration
                ;;
            4)
                return 0
                ;;
            *)
                print_error "Opção inválida"
                ;;
        esac

        echo ""
        read -p "Pressione ENTER para continuar..."
    done
}

#############################################
# MODO NÃO-INTERATIVO
#############################################

# Parse argumentos de linha de comando
parse_cli_arguments() {
    if [ $# -eq 0 ]; then
        return 1  # Modo interativo
    fi

    local action=""
    local platform=""
    local name=""
    local email=""
    local key_type="ed25519"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --create)
                action="create"
                shift
                ;;
            --list)
                action="list"
                shift
                ;;
            --test)
                action="test"
                shift
                ;;
            --backup)
                action="backup"
                shift
                ;;
            --report)
                action="report"
                shift
                ;;
            --platform)
                platform="$2"
                shift 2
                ;;
            --name)
                name="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --type)
                key_type="$2"
                shift 2
                ;;
            --help|-h)
                show_cli_help
                exit 0
                ;;
            *)
                print_error "Argumento desconhecido: $1"
                show_cli_help
                exit 1
                ;;
        esac
    done

    case $action in
        create)
            if [ -z "$platform" ] || [ -z "$name" ]; then
                print_error "Modo create requer --platform e --name"
                exit 1
            fi
            cli_create_key "$platform" "$name" "$email" "$key_type"
            ;;
        list)
            list_ssh_keys
            ;;
        test)
            if [ -z "$platform" ]; then
                print_error "Modo test requer --platform"
                exit 1
            fi
            cli_test_connection "$platform"
            ;;
        backup)
            backup_ssh_directory
            ;;
        report)
            generate_report
            ;;
        *)
            print_error "Ação não especificada"
            show_cli_help
            exit 1
            ;;
    esac

    exit 0
}

# Ajuda do modo CLI
show_cli_help() {
    cat << EOF

${BOLD}USO:${NC}
  ./ssh-key-generator.sh [OPÇÕES]

${BOLD}OPÇÕES:${NC}
  --create              Criar nova chave SSH
  --list                Listar chaves existentes
  --test                Testar conexão SSH
  --backup              Fazer backup do diretório SSH
  --report              Gerar relatório de chaves

  --platform <nome>     Plataforma: github, gitlab, bitbucket
  --name <id>           Identificador único
  --email <email>       Email (opcional)
  --type <tipo>         Tipo de chave: ed25519 (padrão) ou rsa

  -h, --help            Exibir esta ajuda

${BOLD}EXEMPLOS:${NC}
  # Modo interativo (padrão)
  ./ssh-key-generator.sh

  # Criar chave via CLI
  ./ssh-key-generator.sh --create --platform github --name pessoal --email user@email.com

  # Listar chaves
  ./ssh-key-generator.sh --list

  # Testar conexão
  ./ssh-key-generator.sh --test --platform github

  # Fazer backup
  ./ssh-key-generator.sh --backup

EOF
}

# Cria chave via CLI
cli_create_key() {
    local platform="$1"
    local name="$2"
    local email="$3"
    local key_type="$4"

    local hostname=""
    case $platform in
        github)
            hostname="github.com"
            ;;
        gitlab)
            hostname="gitlab.com"
            ;;
        bitbucket)
            hostname="bitbucket.org"
            ;;
        *)
            print_error "Plataforma inválida: $platform"
            exit 1
            ;;
    esac

    if ! validate_identifier "$name"; then
        exit 1
    fi

    if [ -n "$email" ]; then
        if ! validate_email "$email"; then
            exit 1
        fi
    fi

    local key_name="${platform}_${name}"
    local key_path="$SSH_DIR/$key_name"

    if check_key_exists "$key_path"; then
        print_error "Chave '$key_name' já existe!"
        exit 1
    fi

    print_info "Gerando chave SSH $key_type..."

    if [ "$key_type" = "rsa" ]; then
        if [ -n "$email" ]; then
            ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_path" -N ""
        else
            ssh-keygen -t rsa -b 4096 -f "$key_path" -N ""
        fi
    else
        if [ -n "$email" ]; then
            ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
        else
            ssh-keygen -t ed25519 -f "$key_path" -N ""
        fi
    fi

    if [ $? -ne 0 ]; then
        print_error "Falha ao gerar chave SSH"
        exit 1
    fi

    set_permissions "$key_path"
    print_success "Chave SSH criada: $key_path"
    
    add_to_ssh_agent "$key_path"
    update_ssh_config "$platform" "$name" "$key_path" "$hostname"
    
    echo ""
    echo "Chave pública:"
    local public_key=$(cat "${key_path}.pub")
    echo "$public_key"
    
    # Copiar para área de transferência
    if check_clipboard_support; then
        if copy_to_clipboard "$public_key"; then
            echo ""
            print_success "Chave pública copiada para a área de transferência!"
        fi
    fi
}

# Testa conexão via CLI
cli_test_connection() {
    local platform="$1"

    local test_host=""
    case $platform in
        github)
            test_host="git@github.com"
            ;;
        gitlab)
            test_host="git@gitlab.com"
            ;;
        bitbucket)
            test_host="git@bitbucket.org"
            ;;
        *)
            print_error "Plataforma inválida: $platform"
            exit 1
            ;;
    esac

    # Procurar chaves para a plataforma
    local keys=()
    for key in "$SSH_DIR"/*; do
        if [ -f "$key" ] && [ "${key##*.}" != "pub" ] && [ "$(basename "$key")" != "config" ] && [ "$(basename "$key")" != "known_hosts" ]; then
            if [ -f "${key}.pub" ]; then
                local key_name=$(basename "$key")
                if [[ "$key_name" == ${platform}* ]]; then
                    keys+=("$key")
                fi
            fi
        fi
    done

    if [ ${#keys[@]} -eq 0 ]; then
        print_warning "Nenhuma chave encontrada para $platform"
        print_info "Testando com chave padrão..."
        ssh -T "$test_host" 2>&1
    else
        # Usar a primeira chave encontrada
        local key_to_use="${keys[0]}"
        local key_name=$(basename "$key_to_use")
        print_info "Testando conexão com $test_host usando $key_name..."
        ssh -i "$key_to_use" -T "$test_host" 2>&1
    fi

    local exit_code=$?
    if [ $exit_code -eq 1 ] || [ $exit_code -eq 0 ]; then
        print_success "Conexão bem-sucedida!"
    else
        print_error "Falha na conexão"
        exit 1
    fi
}

#############################################
# FUNÇÃO PRINCIPAL
#############################################

main() {
    # Detectar SO
    detect_os

    # Verificar argumentos CLI
    parse_cli_arguments "$@"

    # Verificar dependências
    if ! check_requirements; then
        exit 1
    fi

    # Garantir que o diretório SSH existe
    ensure_ssh_directory

    # Loop principal (modo interativo)
    while true; do
        clear
        show_logo
        show_menu
        print_prompt "Escolha uma opção:"
        read -r choice

        case $choice in
            1)
                create_ssh_key
                ;;
            2)
                list_ssh_keys
                ;;
            3)
                test_connection
                ;;
            4)
                add_key_to_agent_menu
                ;;
            5)
                show_public_key
                ;;
            6)
                echo ""
                print_info "Use a opção 1 para criar chave e configurar automaticamente"
                print_info "Ou edite manualmente: $CONFIG_FILE"
                ;;
            7)
                delete_ssh_key
                ;;
            8)
                backup_and_reports_menu
                ;;
            9)
                echo ""
                print_success "Obrigado por usar o SSH Key Generator!"
                echo ""
                exit 0
                ;;
            *)
                print_error "Opção inválida"
                ;;
        esac

        echo ""
        read -p "Pressione ENTER para continuar..."
    done
}

# Iniciar script
main "$@"
