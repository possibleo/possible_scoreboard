import { Injectable, isDevMode, signal, computed, effect, OnDestroy } from "@angular/core";
import { fromEvent, Observable, Subject, Subscription } from "rxjs";

interface NuiMessage<T = any> {
	action: string;
	data: T;
}

@Injectable({
	providedIn: "root"
})
export class NuiService implements OnDestroy {
	private readonly resourceName = signal<string>(
		(window as any).GetParentResourceName
			? (window as any).GetParentResourceName()
			: "nui-app"
	);

	private readonly lastMessages = signal<Record<string, any>>({});
	private readonly actionObservables: Record<string, Subject<any>> = {};
	private messageSubscription: Subscription;

	constructor() {
		this.messageSubscription = fromEvent<MessageEvent<NuiMessage>>(window, "message").subscribe((event: MessageEvent<NuiMessage>) => {
			this.lastMessages.update(messages => ({
				...messages,
				[event.data.action]: event.data
			}));
			
			if (this.actionObservables[event.data.action]) {
				this.actionObservables[event.data.action].next(event.data.data);
			}
		});
	}

	ngOnDestroy() {
		this.messageSubscription?.unsubscribe();
		Object.values(this.actionObservables).forEach(subject => subject.complete());
	}

	public readonly isEnvBrowser = computed(() => !(window as any).invokeNative);

	async fetchNui<T = any>(eventName: string, data?: any, mockData?: T): Promise<T> {
		if (this.isEnvBrowser() && mockData) {
			return mockData;
		}

		const options = {
			method: "post",
			headers: {
				"Content-Type": "application/json; charset=UTF-8"
			},
			body: JSON.stringify(data)
		};

		const response = await fetch(`https://${this.resourceName()}/${eventName}`, options);
		return await response.json();
	}

	public fromMessageAction<T = any>(action: string): Subject<T> {
		if (!this.actionObservables[action]) {
			this.actionObservables[action] = new Subject<T>();
		}
		return this.actionObservables[action];
	}

	public getLastMessageData<T = any>(action: string): T | false {
		return this.lastMessages()[action] ?? false;
	}

	public dispatchDebugMessages<P>(events: NuiMessage<P>[], timeout = 1000): void {
		if (isDevMode() && this.isEnvBrowser()) {
			for (const event of events) {
				setTimeout(() => {
					window.dispatchEvent(new MessageEvent("message", { data: event }));
				}, timeout);
			}
		}
	}
}
