
import {
    Component,
    ChangeDetectionStrategy,
    ChangeDetectorRef,
    OnInit,
    OnDestroy,
    inject,
    signal,
    computed,
    ViewChild,
    HostListener
} from '@angular/core';
import { Subscription } from 'rxjs';
import { DialogModule } from 'primeng/dialog';
import { TagModule } from 'primeng/tag';
import { ContextMenu, ContextMenuModule } from 'primeng/contextmenu';
import { TooltipModule } from 'primeng/tooltip';
import { ToggleSwitchModule } from 'primeng/toggleswitch';
import { FormsModule } from '@angular/forms';
import { MenuItem } from 'primeng/api';
import { NuiService } from '../nui.service';
import { ScoreboardPlayer, ScoreboardConfig, PlayerDetails, StaffActionResult, PlayerIdentifiers, Locales } from '../types/nui.types';

interface Tab {
    id: string;
    label: string;
    job?: string;
}

@Component({
    selector: 'app-scoreboard',
    standalone: true,
    imports: [DialogModule, TagModule, ContextMenuModule, TooltipModule, ToggleSwitchModule, FormsModule],
    templateUrl: './scoreboard.component.html',
    styleUrl: './scoreboard.component.scss',
    changeDetection: ChangeDetectionStrategy.OnPush
})
export class ScoreboardComponent implements OnInit, OnDestroy {
    @ViewChild('contextMenu') contextMenu!: ContextMenu;

    private nui = inject(NuiService);
    private cdr = inject(ChangeDetectorRef);
    private subscriptions: Subscription[] = [];

    @HostListener('window:keydown', ['$event'])
    handleKeyDown(event: KeyboardEvent): void {
        if (event.key === 'Escape' && this.visible()) {
            event.preventDefault();
            this.closeScoreboard();
        }
    }

    visible = signal(false);
    players = signal<ScoreboardPlayer[]>([]);
    config = signal<ScoreboardConfig | null>(null);
    activeTab = signal<string>('all');
    showSteamNames = false;

    selectedPlayer = signal<ScoreboardPlayer | null>(null);
    playerDetails = signal<PlayerDetails | null>(null);
    showDetailsModal = signal(false);
    detailsLoading = signal(false);

    frozenPlayers = signal<Set<number>>(new Set());
    spectatingPlayerId = signal<number | null>(null);
    spectatingPlayerName = signal<string | null>(null);
    isCurrentlySpectating = signal(false);

    locales = signal<Locales>({
        players_online: 'Players Online',
        no_players: 'No players found',
        player_details: 'Player Details',
        teleport_to_player: 'Teleport to Player',
        bring_player: 'Bring Player',
        freeze_player: 'Freeze Player',
        unfreeze_player: 'Unfreeze Player',
        spectate_player: 'Spectate Player',
        stop_spectating: 'Stop Spectating',
        view_details: 'View Details',
        player_frozen: 'Player Frozen',
        spectating_player: 'Spectating Player',
        close: 'Close',
        scroll_view_more: 'View more',
        spectating: 'Spectating',
        loading: 'Loading...',
        identifiers: 'Identifiers',
        col_id: 'ID',
        col_name: 'Name',
        col_ping: 'Ping',
        col_job: 'Job',
        not_available: 'N/A',
        staff: 'Staff',
        steam_name: 'Steam Name',
        rp_name: 'RP Name'
    });

    isViewerStaff = computed(() => this.config()?.isViewerStaff ?? false);

    contextMenuItems = computed<MenuItem[]>(() => {
        if (!this.isViewerStaff()) return [];
        const player = this.selectedPlayer();
        const isFrozen = player ? this.frozenPlayers().has(player.id) : false;
        const isSpectating = player ? this.spectatingPlayerId() === player.id : false;
        const l = this.locales();

        return [
            { label: l.teleport_to_player, icon: 'pi pi-map-marker', command: () => this.executeStaffAction('teleport') },
            { label: l.bring_player, icon: 'pi pi-user-plus', command: () => this.executeStaffAction('bring') },
            {
                label: isFrozen ? l.unfreeze_player : l.freeze_player,
                icon: isFrozen ? 'pi pi-lock-open' : 'pi pi-lock',
                command: () => this.executeStaffAction('freeze')
            },
            {
                label: isSpectating ? l.stop_spectating : l.spectate_player,
                icon: isSpectating ? 'pi pi-eye-slash' : 'pi pi-eye',
                command: () => this.executeStaffAction('spectate')
            },
            { separator: true },
            { label: l.view_details, icon: 'pi pi-info-circle', command: () => this.openDetailsModal() }
        ];
    });

    tabs = computed<Tab[]>(() => {
        const cfg = this.config();
        const baseTabs: Tab[] = [{ id: 'all', label: 'All' }];

        if (cfg?.jobs) {
            cfg.jobs.forEach(job => {
                baseTabs.push({ id: job.job, label: job.label, job: job.job });
            });
        }

        baseTabs.push({ id: 'staff', label: 'Staff' });

        return baseTabs;
    });

    filteredPlayers = computed(() => {
        const tab = this.activeTab();
        const allPlayers = this.players();

        if (tab === 'all') {
            return allPlayers;
        }

        if (tab === 'staff') {
            return allPlayers.filter(p => p.isStaff);
        }

        return allPlayers.filter(p => p.job === tab);
    });

    getTabCount(tabId: string): number {
        const allPlayers = this.players();

        if (tabId === 'all') {
            return allPlayers.length;
        }

        if (tabId === 'staff') {
            return allPlayers.filter(p => p.isStaff).length;
        }

        return allPlayers.filter(p => p.job === tabId).length;
    }

    getDisplayName(player: ScoreboardPlayer): string {
        return this.showSteamNames ? player.steamName : player.name;
    }

    onToggleSteamNames(event: { checked: boolean }): void {
        this.showSteamNames = event.checked;
        this.cdr.markForCheck();
    }

    playerCount = computed(() => this.filteredPlayers().length);

    ngOnInit(): void {
        this.subscriptions.push(
            this.nui.fromMessageAction<boolean>('setVisible').subscribe(value => {
                this.visible.set(value);
                if (value) {
                    this.loadData();
                }
            })
        );

        this.subscriptions.push(
            this.nui.fromMessageAction<{ active: boolean; playerId?: number; playerName?: string }>('setSpectating').subscribe(data => {
                this.isCurrentlySpectating.set(data.active);
                if (data.active && data.playerId && data.playerName) {
                    this.spectatingPlayerId.set(data.playerId);
                    this.spectatingPlayerName.set(data.playerName);
                } else {
                    this.spectatingPlayerId.set(null);
                    this.spectatingPlayerName.set(null);
                }
            })
        );

        this.nui.dispatchDebugMessages([
            { action: 'setVisible', data: true }
        ]);

        if (this.nui.isEnvBrowser()) {
            this.loadMockData();
        }
    }

    ngOnDestroy(): void {
        this.subscriptions.forEach(sub => sub.unsubscribe());
    }

    private async loadData(): Promise<void> {
        try {
            const [playersData, configData, localesData] = await Promise.all([
                this.nui.fetchNui<ScoreboardPlayer[]>('getPlayers'),
                this.nui.fetchNui<ScoreboardConfig>('getConfig'),
                this.nui.fetchNui<Locales>('getLocales')
            ]);

            this.players.set(playersData || []);
            this.config.set(configData || null);
            if (localesData) {
                this.locales.set(localesData);
            }
        } catch (error) {
            console.error('Failed to load scoreboard data:', error);
        }
    }

    private loadMockData(): void {
        this.players.set([
            { id: 1, name: 'John Smith', steamName: 'jsmith_ttv', ping: 45, job: 'police', isStaff: true },
            { id: 2, name: 'Jane Doe', steamName: 'janedoe92', ping: 32, job: 'ambulance', isStaff: false },
            { id: 3, name: 'Mike Johnson', steamName: 'mikej_gaming', ping: 78, job: 'police', isStaff: false },
            { id: 4, name: 'Sarah Williams', steamName: 'swilliams', ping: 23, job: 'civilian', isStaff: false },
            { id: 5, name: 'David Brown', steamName: 'dbrown123', ping: 156, job: 'mechanic', isStaff: false },
            { id: 6, name: 'Emily Davis', steamName: 'emily_d', ping: 42, job: 'ambulance', isStaff: false },
            { id: 7, name: 'Chris Wilson', steamName: 'chriswilson', ping: 67, job: 'police', isStaff: true },
            { id: 8, name: 'Amanda Taylor', steamName: 'ataylor_rp', ping: 89, job: 'civilian', isStaff: false },
            { id: 9, name: 'Ryan Martinez', steamName: 'ryanm', ping: 34, job: 'mechanic', isStaff: false },
            { id: 10, name: 'Jessica Anderson', steamName: 'jessicaa', ping: 51, job: 'civilian', isStaff: false },
            { id: 11, name: 'Kevin Thomas', steamName: 'kthomas', ping: 28, job: 'police', isStaff: false },
            { id: 12, name: 'Nicole Jackson', steamName: 'njackson', ping: 112, job: 'ambulance', isStaff: false },
            { id: 13, name: 'Marcus Lee', steamName: 'mlee_ttv', ping: 19, job: 'civilian', isStaff: true },
            { id: 14, name: 'Sophia Garcia', steamName: 'sophiag', ping: 63, job: 'police', isStaff: false },
            { id: 15, name: 'Tyler Robinson', steamName: 'tyler_r', ping: 95, job: 'civilian', isStaff: false },
            { id: 16, name: 'Olivia White', steamName: 'owhite', ping: 37, job: 'mechanic', isStaff: false },
            { id: 17, name: 'Ethan Harris', steamName: 'ethanh', ping: 142, job: 'civilian', isStaff: false },
            { id: 18, name: 'Mia Thompson', steamName: 'miat', ping: 55, job: 'ambulance', isStaff: false },
            { id: 19, name: 'Lucas Clark', steamName: 'lucasc', ping: 81, job: 'civilian', isStaff: false },
            { id: 20, name: 'Ava Rodriguez', steamName: 'avar', ping: 26, job: 'civilian', isStaff: false },
        ]);

        this.config.set({
            showServices: true,
            theme: {
                primary: {
                    50: '240, 249, 255',
                    100: '#e0f2fe',
                    200: '#bae6fd',
                    300: '#7dd3fc',
                    400: '56, 189, 248',
                    500: '14, 165, 233',
                    600: '#0284c7',
                    700: '3, 105, 161',
                    800: '#075985',
                    900: '12, 74, 110',
                    950: '8, 47, 73'
                }
            },
            jobs: [
                { job: 'police', label: 'Police' },
                { job: 'ambulance', label: 'EMS' },
                { job: 'mechanic', label: 'Mechanic' },
            ],
            staffAces: ['group.admin', 'group.mod'],
            isViewerStaff: true,
            localPlayerId: 1
        });
    }

    setActiveTab(tabId: string): void {
        this.activeTab.set(tabId);
    }

    getPingClass(ping: number): 'success' | 'warn' | 'danger' {
        if (ping < 60) return 'success';
        if (ping < 120) return 'warn';
        return 'danger';
    }

    onHide(): void {
        if (!this.nui.isEnvBrowser()) {
            this.nui.fetchNui('hideFrame');
        }
    }

    closeScoreboard(): void {
        this.visible.set(false);
        if (!this.nui.isEnvBrowser()) {
            this.nui.fetchNui('hideFrame');
        }
    }

    isPlayerFrozen(playerId: number): boolean {
        return this.frozenPlayers().has(playerId);
    }

    isPlayerSpectated(playerId: number): boolean {
        return this.spectatingPlayerId() === playerId;
    }

    hasActiveAction(playerId: number): boolean {
        return this.isPlayerFrozen(playerId) || this.isPlayerSpectated(playerId);
    }

    stopSpectating(): void {
        this.nui.fetchNui('stopSpectating');
    }

    onPlayerContextMenu(event: MouseEvent, player: ScoreboardPlayer): void {
        if (!this.isViewerStaff()) return;
        const localId = this.config()?.localPlayerId;
        if (localId && player.id === localId) return;
        event.preventDefault();
        this.selectedPlayer.set(player);
        this.contextMenu.show(event);
    }

    async executeStaffAction(action: 'teleport' | 'bring' | 'freeze' | 'spectate'): Promise<void> {
        const player = this.selectedPlayer();
        if (!player) return;

        try {
            const result = await this.nui.fetchNui<StaffActionResult>('staffAction', {
                action,
                targetPlayerId: player.id
            });

            if (result?.success) {
                if (action === 'freeze') {
                    const newFrozen = new Set(this.frozenPlayers());
                    if (result.frozen) {
                        newFrozen.add(player.id);
                    } else {
                        newFrozen.delete(player.id);
                    }
                    this.frozenPlayers.set(newFrozen);
                }

                if (action === 'spectate') {
                    const currentSpectating = this.spectatingPlayerId();
                    if (currentSpectating === player.id) {
                        this.spectatingPlayerId.set(null);
                    } else {
                        this.spectatingPlayerId.set(player.id);
                    }
                    this.visible.set(false);
                    this.nui.fetchNui('hideFrame');
                }

                if (action === 'teleport' || action === 'bring') {
                    this.visible.set(false);
                    this.nui.fetchNui('hideFrame');
                }
            }
        } catch (error) {
            console.error('Staff action error:', error);
        }
    }

    async openDetailsModal(): Promise<void> {
        const player = this.selectedPlayer();
        if (!player) return;

        this.detailsLoading.set(true);
        this.showDetailsModal.set(true);

        try {
            const details = await this.nui.fetchNui<PlayerDetails>('getPlayerDetails', {
                targetPlayerId: player.id
            });

            if (details) {
                this.playerDetails.set(details);
            } else {
                this.playerDetails.set({
                    ...player,
                    identifiers: {
                        steam: '110000123456789',
                        discord: '123456789012345678',
                        license: 'abcdef1234567890abcdef1234567890abcdef12',
                        fivem: '1234567'
                    }
                });
            }
        } catch (error) {
            console.error('Failed to load player details:', error);
            this.playerDetails.set({
                ...player,
                identifiers: {
                    steam: '110000123456789',
                    discord: '123456789012345678',
                    license: 'abcdef1234567890abcdef1234567890abcdef12',
                    fivem: '1234567'
                }
            });
        } finally {
            this.detailsLoading.set(false);
        }
    }

    onDetailsModalHide(): void {
        this.playerDetails.set(null);
    }
    getIdentifierEntries(identifiers: PlayerIdentifiers): { key: string; value: string }[] {
        return Object.entries(identifiers as Record<string, string | undefined>)
            .filter(([_, value]) => value !== undefined)
            .map(([key, value]) => ({ key, value: value as string }));
    }

}
