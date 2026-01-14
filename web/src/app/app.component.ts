import { Component } from '@angular/core';
import { ScoreboardComponent } from './scoreboard/scoreboard.component';

@Component({
    selector: 'app-root',
    standalone: true,
    imports: [ScoreboardComponent],
    templateUrl: './app.component.html',
    styleUrl: './app.component.scss'
})
export class AppComponent {}
