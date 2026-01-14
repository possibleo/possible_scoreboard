declare global {
    interface Window {
        GetParentResourceName?: () => string;
        invokeNative?: (native: string, ...args: unknown[]) => unknown;
    }
}

export interface NuiMessage<T = unknown> {
    action: string;
    data: T;
}

export interface ThemeConfig {
    primary: {
        50: string;
        100: string;
        200: string;
        300: string;
        400: string;
        500: string;
        600: string;
        700: string;
        800: string;
        900: string;
        950: string;
    };
}

export interface ScoreboardPlayer {
    id: number;
    name: string;
    steamName: string;
    ping: number;
    job?: string;
    isStaff?: boolean;
}

export interface JobTab {
    job: string;
    label: string;
}

export interface ScoreboardConfig {
    showServices: boolean;
    theme: ThemeConfig;
    jobs: JobTab[];
    staffAces: string[];
    isViewerStaff: boolean;
    localPlayerId: number;
}

export interface PlayerIdentifiers {
    steam?: string;
    discord?: string;
    license?: string;
    license2?: string;
    fivem?: string;
    xbox?: string;
    live?: string;
}

export interface PlayerDetails extends ScoreboardPlayer {
    identifiers: PlayerIdentifiers;
}

export interface StaffActionPayload {
    action: 'teleport' | 'bring' | 'freeze' | 'spectate';
    targetPlayerId: number;
}

export interface StaffActionResult {
    success: boolean;
    message?: string;
    frozen?: boolean;
}

export interface Locales {
    players_online: string;
    no_players: string;
    player_details: string;
    teleport_to_player: string;
    bring_player: string;
    freeze_player: string;
    unfreeze_player: string;
    spectate_player: string;
    stop_spectating: string;
    view_details: string;
    player_frozen: string;
    spectating_player: string;
    close: string;
    scroll_view_more: string;
    spectating: string;
    loading: string;
    identifiers: string;
    col_id: string;
    col_name: string;
    col_ping: string;
    col_job: string;
    not_available: string;
    staff: string;
    steam_name: string;
    rp_name: string;
}
