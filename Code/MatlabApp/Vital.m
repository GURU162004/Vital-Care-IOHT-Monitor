function InteractiveDashboard_Final
    clc; close all;
    app.IsRunning = false;
    app.IsConnected = false;
    app.Device = [];
    COM_PORT = "COM14"; 
    BAUD_RATE = 115200;
    SAMPLE_RATE = 50;
    LOGGING_INTERVAL_SEC = 2; 
    ANALYSIS_INTERVAL_SEC = 15; 
    createUI();
    function createUI()
        app.UIFigure = uifigure('Name', 'Cognitive Biofeedback Dashboard', 'Position', [100 100, 1100, 750], 'CloseRequestFcn', @onClose);
        gridLayout = uigridlayout(app.UIFigure, [2, 2], 'RowHeight', {'1x', 50}, 'ColumnWidth', {'1.5x', '1.2x'});
        leftPanel = uipanel(gridLayout);
        leftPanel.Layout.Row = 1; leftPanel.Layout.Column = 1;
        leftGridLayout = uigridlayout(leftPanel, [2,1], 'RowHeight', {'2x', '1x'});
        app.LivePPGSignalAxes = uiaxes(leftGridLayout);
        title(app.LivePPGSignalAxes, 'Live PPG Signal (IR)');
        xlabel(app.LivePPGSignalAxes, 'Samples');
        ylabel(app.LivePPGSignalAxes, 'Amplitude');
        grid(app.LivePPGSignalAxes, 'on');
        vitalsPanel = uipanel(leftGridLayout, 'Title', 'Real-Time Vitals');
        vitalsLayout = uigridlayout(vitalsPanel, [2,2]);
        app.HeartRateLabel = uilabel(vitalsLayout, 'Text', 'Heart Rate: -- BPM', 'FontSize', 18);
        app.SpO2Label = uilabel(vitalsLayout, 'Text', 'SpO2: -- %', 'FontSize', 18);
        app.TimerLabel = uilabel(vitalsLayout, 'Text', '00:00', 'FontSize', 28, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        app.TimerLabel.Layout.Row = [1 2]; app.TimerLabel.Layout.Column = 2;
        rightPanel = uipanel(gridLayout);
        rightPanel.Layout.Row = 1; rightPanel.Layout.Column = 2;
        rightGridLayout = uigridlayout(rightPanel, [2,1]);
        rangesPanel = uipanel(rightGridLayout, 'Title', 'Reference Values');
        imageLayout = uigridlayout(rangesPanel, [1, 1], 'Padding', 0); 
        app.NormalRangesImage = uiimage(imageLayout); 
        app.NormalRangesImage.ImageSource = createRangesImage(); 
        app.NormalRangesImage.ScaleMethod = 'stretch';    
        hrvPanel = uipanel(rightGridLayout, 'Title', 'HRV & Cognitive State');
        hrvLayout = uigridlayout(hrvPanel, [4,1]);
        app.RespRateLabel = uilabel(hrvLayout, 'Text', 'Resp. Rate: -- BreathsPM', 'FontSize', 14);
        app.RMSSDLabel = uilabel(hrvLayout, 'Text', 'HRV (RMSSD): -- ms', 'FontSize', 14);
        app.SDNNLabel = uilabel(hrvLayout, 'Text', 'HRV (SDNN): -- ms', 'FontSize', 14);
        app.CognitiveStateLabel = uilabel(hrvLayout, 'Text', 'Cognitive State: --', 'FontSize', 16, 'FontWeight', 'bold');
        bottomPanel = uipanel(gridLayout);
        bottomPanel.Layout.Row = 2; bottomPanel.Layout.Column = [1 2];
        app.ConnectButton = uibutton(bottomPanel, 'push', 'Text', 'Connect to Pico', 'Position', [20, 10, 120, 23], 'ButtonPushedFcn', @connectButtonPushed);
        app.StartButton = uibutton(bottomPanel, 'push', 'Text', 'Start Session', 'Position', [160, 10, 100, 23], 'ButtonPushedFcn', @startButtonPushed, 'Enable', 'off');
        app.StopButton = uibutton(bottomPanel, 'push', 'Text', 'Stop Session', 'Position', [280, 10, 100, 23], 'ButtonPushedFcn', @stopButtonPushed, 'Enable', 'off');
        uilabel(bottomPanel, 'Text', 'Session Status:', 'Position', [400, 10, 90, 22]);
        app.SessionLamp = uilamp(bottomPanel, 'Position', [495, 10, 20, 20], 'Color', 'r');
        uilabel(bottomPanel, 'Text', 'Device Status:', 'Position', [950, 10, 85, 22]);
        app.StatusLamp = uilamp(bottomPanel, 'Position', [1045, 10, 20, 20], 'Color', 'r');
    end

    function connectButtonPushed(~, ~)
        if ~app.IsConnected
            try
                app.Device = serialport(COM_PORT, BAUD_RATE);
                configureTerminator(app.Device, "LF");
                app.StatusLamp.Color = 'g'; app.ConnectButton.Text = 'Disconnect';
                app.StartButton.Enable = 'on'; app.IsConnected = true;
                disp("Connected to Raspberry Pi Pico.");
            catch e, uialert(app.UIFigure, ['Failed to connect: ', e.message], 'Connection Error'); end
        else
            clear app.Device; app.StatusLamp.Color = 'r';
            app.ConnectButton.Text = 'Connect to Pico'; app.StartButton.Enable = 'off';
            app.IsConnected = false; disp("Disconnected from device.");
        end
    end

    function startButtonPushed(~, ~)
        app.IsRunning = true;
        app.StartButton.Enable = 'off'; app.ConnectButton.Enable = 'off';
        app.StopButton.Enable = 'on';
        app.SessionLamp.Color = 'g'; 
        
        cla(app.LivePPGSignalAxes);
        hPlot = animatedline(app.LivePPGSignalAxes, 'Color', 'b');
        dataLogBuffer = [];
        
        irChngStor = zeros(1, 5); prev_ir = 0;
        bpmStor = zeros(1, 10); spO2Stor = zeros(1, 20);
        lookpeak = true; beat_timer = tic;
        irHigh = 0; irLow = inf; redHigh = 0; redLow = inf;
        ir_window_buffer = []; rr_interval_buffer = []; 
        analysis_timer = tic; log_timer = tic;
        
        heartRate = NaN; spO2 = NaN; rmssd = NaN; sdnn = NaN; respRate = NaN;
        
        sampleCount = 0; sessionStartTime = tic;
        disp("Session Started...");
        
        while app.IsRunning
            line = readline(app.Device);
            newData = str2double(split(line, ','));
            
            if numel(newData) == 2 && ~any(isnan(newData))
                irValue = newData(1); redValue = newData(2);
                sampleCount = sampleCount + 1;
                addpoints(hPlot, sampleCount, irValue);
                
                ir_window_buffer(end+1) = irValue;
                if irValue > irHigh, irHigh = irValue; end; if irValue < irLow, irLow = irValue; end
                if redValue > redHigh, redHigh = redValue; end; if redValue < redLow, redLow = redValue; end
                
                ir_change = irValue - prev_ir; prev_ir = irValue;
                irChngStor = [irChngStor(2:end), ir_change]; avgChng = mean(irChngStor);
                
                if avgChng < -5 && lookpeak
                    interval_sec = toc(beat_timer);
                    if interval_sec > 0.33 
                        bpm = 60 / interval_sec;
                        beat_timer = tic; lookpeak = false;
                        rr_interval_buffer(end+1) = interval_sec * 1000;
                        
                        bpmStor = [bpmStor(2:end), bpm];
                        active_bpm = bpmStor(bpmStor > 0);
                        if numel(active_bpm) > 2, heartRate = mean(sort(active_bpm(2:end-1))); else, heartRate = mean(active_bpm); end
                        
                        current_spo2 = calculate_spo2(redHigh, redLow, irHigh, irLow);
                        if current_spo2 > 80, spO2Stor = [spO2Stor(2:end), current_spo2]; end
                        active_spo2 = spO2Stor(spO2Stor > 0);
                        if numel(active_spo2) > 2, spO2 = mean(sort(active_spo2(2:end-1))); else, spO2 = mean(active_spo2); end
                        
                        irHigh = 0; irLow = inf; redHigh = 0; redLow = inf;
                    end
                end
                if avgChng > 0.5 && ~lookpeak, lookpeak = true; end
                
                if toc(analysis_timer) > ANALYSIS_INTERVAL_SEC
                    if numel(rr_interval_buffer) > 5
                        cleaned_rr = clean_rr_intervals(rr_interval_buffer);
                        if numel(cleaned_rr) > 4, rmssd = sqrt(mean(diff(cleaned_rr).^2)); sdnn = std(cleaned_rr); end
                    end
                    if numel(ir_window_buffer) > 100
                        [up,~] = envelope(ir_window_buffer, 25, 'peak');
                        [~, locs] = findpeaks(up - mean(up), 'MinPeakDistance', 100);
                        if numel(locs) > 1, respRate = 60 / (mean(diff(locs))/SAMPLE_RATE); end
                    end
                    ir_window_buffer = []; rr_interval_buffer = []; analysis_timer = tic;
                end
                
                if toc(log_timer) > LOGGING_INTERVAL_SEC
                    currentTime = toc(sessionStartTime);
                    dataLogBuffer(end+1, :) = [currentTime, irValue, redValue, heartRate, spO2, rmssd, sdnn, respRate];
                    log_timer = tic;
                end
                
                if ~isnan(heartRate), app.HeartRateLabel.Text = sprintf('Heart Rate: %.1f BPM', heartRate); end
                if ~isnan(spO2), app.SpO2Label.Text = sprintf('SpO2: %.1f %%', spO2); end
                if ~isnan(rmssd), app.RMSSDLabel.Text = sprintf('HRV (RMSSD): %.1f ms', rmssd); end
                if ~isnan(sdnn), app.SDNNLabel.Text = sprintf('HRV (SDNN): %.1f ms', sdnn); end
                if ~isnan(respRate), app.RespRateLabel.Text = sprintf('Resp. Rate: %.1f BreathsPM', respRate); end
                if ~isnan(rmssd) && ~isnan(sdnn)
                    if rmssd > 50, app.CognitiveStateLabel.Text = 'Cognitive State: RELAXED';
                    elseif rmssd < 20, app.CognitiveStateLabel.Text = 'Cognitive State: STRESSED';
                    else, app.CognitiveStateLabel.Text = 'Cognitive State: FOCUSED';
                    end
                end
                
                elapsedTime = toc(sessionStartTime);
                mins = floor(elapsedTime / 60); secs = floor(mod(elapsedTime, 60));
                app.TimerLabel.Text = sprintf('%02d:%02d', mins, secs);
                
                drawnow;
            end
        end
        saveData(dataLogBuffer);
    end

    function stopButtonPushed(~, ~)
        if ~app.IsRunning, return; end
        app.IsRunning = false;
        app.StopButton.Enable = 'off';
        app.StartButton.Enable = 'on';
        app.ConnectButton.Enable = 'on';
        app.SessionLamp.Color = 'r'; % Session is stopped
    end
    
    function saveData(logBuffer)
        if ~isempty(logBuffer)
            timestamp = datestr(now, 'yyyymmdd_HHMMSS');
            filename = ['Session_Data_', timestamp, '.csv'];
            T = array2table(logBuffer, 'VariableNames', {'Timestamp', 'IR', 'Red', 'HR', 'SpO2', 'RMSSD', 'SDNN', 'RespRate'});
            writetable(T, filename);
            disp(['Session stopped. Data saved to ', filename]);
        else
            disp('Session stopped. No data was recorded.');
        end
    end

    function onClose(~, ~)
        app.IsRunning = false;
        if app.IsConnected, clear app.Device; end
        delete(gcf);
    end
    
    function img = createRangesImage()
        fig_hidden = uifigure('Visible', 'off', 'Position', [0 0 2400 1500]);
        normalData = {
            'Heart Rate', '60 - 100 BPM';
            'SpO₂', '95% - 100%';
            'Resp. Rate', '12 - 20 BreathsPM'
            };
        hrvData = {
            'Relaxed', '> 50', '> 60';
            'Focused / Active', '20 - 50', '30 - 60';
            'Stressed / Fatigued', '< 20', '< 30'
            };
        uilabel(fig_hidden, 'Text', 'Normal Resting Ranges', ...
            'Position', [50, 720, 1100, 100], ...
            'FontSize', 28, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        t1 = uitable(fig_hidden, 'Data', normalData, ...
            'ColumnName', {'Metric', 'Value'}, ...
            'RowName', [], ...
            'Position', [100, 560, 1000, 150], ...
            'FontSize', 24, 'ColumnWidth', {300, 'auto'});
        uilabel(fig_hidden, 'Text', 'HRV Ranges by Cognitive State', ...
            'Position', [50, 460, 1100, 100], ...
            'FontSize', 28, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
        t2 = uitable(fig_hidden, 'Data', hrvData, ...
            'ColumnName', {'Cognitive State', 'RMSSD (ms)', 'SDNN (ms)'}, ...
            'RowName', [], ...
            'Position', [100, 200, 1000, 250], ...
            'FontSize', 24, 'ColumnWidth', {350, 'auto', 'auto'});
        frame = getframe(fig_hidden);
        img = frame.cdata;
        close(fig_hidden);
    end
    
    
    function cleaned = clean_rr_intervals(intervals)
        if isempty(intervals), cleaned = []; return; end
        median_rr = median(intervals);
        min_rr = median_rr * 0.80; max_rr = median_rr * 1.20;
        cleaned = intervals(intervals > min_rr & intervals < max_rr);
    end

    function spO2 = calculate_spo2(red_max, red_min, ir_max, ir_min)
        red_AC = red_max - red_min; red_DC = (red_max + red_min) / 2;
        ir_AC = ir_max - ir_min; ir_DC = (ir_max + ir_min) / 2;
        if red_DC == 0 || ir_DC == 0 || ir_AC == 0, spO2 = 0; return; end
        R_val = (red_AC / red_DC) / (ir_AC / ir_DC);
        spO2 = 116.6 - (34.5 * R_val);
        if spO2 > 100, spO2 = 100; end
    end

end

