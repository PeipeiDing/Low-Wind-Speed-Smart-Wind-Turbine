%% 风机低启动风能MPPT仿真模型

fprintf('正在创建风机MPPT仿真模型...\n');

modelName = 'Wind_Turbine_MPPT_Simulation';

%% 参数
R = 0.15; L = 0.29; rho = 1.225;
J_total = 0.01; TSR_opt = 4.5;
Kp = 0.5; Ki = 0.1; Vwind = 4;

%% 创建模型
try
    load_system(modelName);
    close_system(modelName, 0);
catch
end
new_system(modelName);
set_param(modelName, 'Solver', 'ode4');
set_param(modelName, 'FixedStep', '0.001');
set_param(modelName, 'StopTime', '10');

fprintf('正在添加模块...\n');

%% 模块列表
% 风速
add_block('simulink/Sources/Constant', [modelName, '/Wind']);
set_param([modelName, '/Wind'], 'Value', num2str(Vwind), 'Position', [50, 100, 100, 130]);

% 转速积分 - 初始条件直接写在模块参数中
add_block('simulink/Continuous/Integrator', [modelName, '/Int_Omega']);
set_param([modelName, '/Int_Omega'], ...
    'InitialCondition', '0.1', ...
    'ExternalReset', 'none', ...
    'Position', [700, 100, 730, 130]);

% TSR计算: lambda = omega*R/Vw
add_block('simulink/Math Operations/Gain', [modelName, '/Gain_R']);
set_param([modelName, '/Gain_R'], 'Gain', num2str(R), 'Position', [180, 100, 210, 130]);

add_block('simulink/Math Operations/Divide', [modelName, '/Div_TSR']);
set_param([modelName, '/Div_TSR'], 'Position', [260, 100, 290, 130]);

% MPPT误差
add_block('simulink/Math Operations/Subtract', [modelName, '/Sub_Err']);
set_param([modelName, '/Sub_Err'], 'Position', [360, 100, 390, 130]);

add_block('simulink/Sources/Constant', [modelName, '/TSR_Ref']);
set_param([modelName, '/TSR_Ref'], 'Value', num2str(TSR_opt), 'Position', [330, 60, 360, 90]);

% PI控制器
add_block('simulink/Math Operations/Gain', [modelName, '/Gain_Kp']);
set_param([modelName, '/Gain_Kp'], 'Gain', num2str(Kp), 'Position', [430, 100, 460, 130]);

add_block('simulink/Continuous/Integrator', [modelName, '/Int_Err']);
set_param([modelName, '/Int_Err'], ...
    'InitialCondition', num2str(TSR_opt), ...
    'Position', [500, 100, 530, 130]);

add_block('simulink/Math Operations/Gain', [modelName, '/Gain_Ki']);
set_param([modelName, '/Gain_Ki'], 'Gain', num2str(Ki), 'Position', [560, 100, 590, 130]);

add_block('simulink/Math Operations/Add', [modelName, '/Add_PI']);
set_param([modelName, '/Add_PI'], 'Position', [620, 100, 650, 130]);

% 扭矩限幅
add_block('simulink/Discontinuities/Saturation', [modelName, '/Sat_Te']);
set_param([modelName, '/Sat_Te'], 'UpperLimit', '3', 'LowerLimit', '0', 'Position', [680, 100, 710, 130]);

% 气动扭矩计算
add_block('simulink/Math Operations/Product', [modelName, '/Prod1']);
set_param([modelName, '/Prod1'], 'Multiplication', 'Element-wise(.*)', 'Position', [160, 180, 190, 230]);

add_block('simulink/Math Operations/Gain', [modelName, '/Gain_Cp']);
set_param([modelName, '/Gain_Cp'], 'Gain', '0.15', 'Position', [210, 180, 240, 220]);

% 防零保护
add_block('simulink/Sources/Constant', [modelName, '/Epsilon']);
set_param([modelName, '/Epsilon'], 'Value', '0.01', 'Position', [260, 200, 290, 230]);

add_block('simulink/Math Operations/Add', [modelName, '/Add_Epsilon']);
set_param([modelName, '/Add_Epsilon'], 'Inputs', '+-', 'Position', [260, 180, 290, 220]);

add_block('simulink/Math Operations/Divide', [modelName, '/Div_Tm']);
set_param([modelName, '/Div_Tm'], 'Position', [300, 180, 330, 220]);

% 传动系统
add_block('simulink/Math Operations/Subtract', [modelName, '/Sub_Dyn']);
set_param([modelName, '/Sub_Dyn'], 'Position', [420, 180, 450, 220]);

add_block('simulink/Math Operations/Gain', [modelName, '/Gain_J']);
set_param([modelName, '/Gain_J'], 'Gain', num2str(1/J_total), 'Position', [480, 180, 510, 220]);

% 示波器
add_block('simulink/Sinks/Scope', [modelName, '/Scope_Wind']);
set_param([modelName, '/Scope_Wind'], 'Position', [50, 300, 100, 350]);
add_block('simulink/Sinks/Scope', [modelName, '/Scope_Omega']);
set_param([modelName, '/Scope_Omega'], 'Position', [200, 300, 250, 350]);
add_block('simulink/Sinks/Scope', [modelName, '/Scope_TSR']);
set_param([modelName, '/Scope_TSR'], 'Position', [350, 300, 400, 350]);
add_block('simulink/Sinks/Scope', [modelName, '/Scope_Tm']);
set_param([modelName, '/Scope_Tm'], 'Position', [500, 300, 550, 350]);

%% 连线
fprintf('正在连接信号线...\n');

% 转速 -> TSR
add_line(modelName, 'Int_Omega/1', 'Gain_R/1');
add_line(modelName, 'Gain_R/1', 'Div_TSR/1');
add_line(modelName, 'Wind/1', 'Div_TSR/2');

% TSR误差
add_line(modelName, 'Div_TSR/1', 'Sub_Err/2');
add_line(modelName, 'TSR_Ref/1', 'Sub_Err/1');

% PI控制 -> Te
add_line(modelName, 'Sub_Err/1', 'Gain_Kp/1');
add_line(modelName, 'Gain_Kp/1', 'Add_PI/1');
add_line(modelName, 'Sub_Err/1', 'Int_Err/1');
add_line(modelName, 'Int_Err/1', 'Gain_Ki/1');
add_line(modelName, 'Gain_Ki/1', 'Add_PI/2');
add_line(modelName, 'Add_PI/1', 'Sat_Te/1');

% Te -> 传动系统
add_line(modelName, 'Sat_Te/1', 'Sub_Dyn/2');
add_line(modelName, 'Sub_Dyn/1', 'Gain_J/1');
add_line(modelName, 'Gain_J/1', 'Int_Omega/1');

% 气动扭矩 -> 传动系统
add_line(modelName, 'Wind/1', 'Prod1/1');
add_line(modelName, 'Wind/1', 'Prod1/2');
add_line(modelName, 'Prod1/1', 'Gain_Cp/1');
add_line(modelName, 'Gain_Cp/1', 'Div_Tm/1');

% 防零保护：omega + epsilon -> Div_Tm
add_line(modelName, 'Epsilon/1', 'Add_Epsilon/2');
add_line(modelName, 'Int_Omega/1', 'Add_Epsilon/1');
add_line(modelName, 'Add_Epsilon/1', 'Div_Tm/2');

add_line(modelName, 'Div_Tm/1', 'Sub_Dyn/1');

% 示波器
add_line(modelName, 'Wind/1', 'Scope_Wind/1');
add_line(modelName, 'Int_Omega/1', 'Scope_Omega/1');
add_line(modelName, 'Div_TSR/1', 'Scope_TSR/1');
add_line(modelName, 'Div_Tm/1', 'Scope_Tm/1');

%% 保存
save_system(modelName, 'Wind_Turbine_MPPT_Simulation.slx');

fprintf('\n========================================\n');
fprintf('风机MPPT仿真模型修复版创建成功！\n');
fprintf('========================================\n');
fprintf('模型: Wind_Turbine_MPPT_Simulation.slx\n');
fprintf('修复: 积分器初始条件直接设置，移除了重复的初始值连接\n');
fprintf('\n使用方法:\n');
fprintf('  open_system(''Wind_Turbine_MPPT_Simulation'')\n');
fprintf('  sim(''Wind_Turbine_MPPT_Simulation'')\n');
fprintf('\n完成！\n');
