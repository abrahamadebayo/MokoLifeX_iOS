//
//  MKDeviceInfoController.m
//  MKSmartPlug
//
//  Created by aa on 2018/6/13.
//  Copyright © 2018年 MK. All rights reserved.
//

#import "MKDeviceInfoController.h"
#import "MKBaseTableView.h"
#import "MKDeviceInfoCell.h"
#import "MKDeviceInfoModel.h"
#import "MKModifyLocalNameView.h"
#import "MKDeviceDataBaseManager.h"


#import "MKDeviceInfoAdopter.h"
#import "MKAboutController.h"
#import "MKDeviceInformationController.h"
#import "MKUpdateFirmwareController.h"
#import "MKModifyPowerOnStatusController.h"

@interface MKDeviceInfoController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong)MKBaseTableView *tableView;

@property (nonatomic, strong)NSMutableArray *dataList;

@end

@implementation MKDeviceInfoController

#pragma mark - life circle
- (void)dealloc{
    NSLog(@"MKDeviceInfoController销毁");
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadSubViews];
    [self getDeviceLocalName];
    // Do any additional setup after loading the view.
}

#pragma mark - 父类方法

#pragma mark - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 44.f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.row == 0) {
        //修改名称
        MKModifyLocalNameView *view = [[MKModifyLocalNameView alloc] init];
        WS(weakSelf);
        [view showConnectAlertViewTitle:@"Modify Device Name" text:self.deviceModel.local_name block:^(BOOL empty, NSString *name) {
            if (empty) {
                [view showCentralToast:@"Device name can't be blank."];
                return ;
            }
            [weakSelf updateDeviceLocalName:name];
        }];
        return;
    }
    if (indexPath.row == 4) {
        //关于
        MKAboutController *vc = [[MKAboutController alloc] init];
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }
    if (![self canClickEnable]) {
        return;
    }
    if (indexPath.row == 1) {
        //设备信息
        [self readFirmwareInfo];
        return;
    }
    if (indexPath.row == 2) {
        //固件升级
        if (self.deviceModel.device_mode == MKDevice_plug && self.deviceModel.plugState == MKSmartPlugOffline) {
            [self.view showCentralToast:@"Device offline,please check."];
            return;
        }
        if (self.deviceModel.device_mode == MKDevice_swich && self.deviceModel.swichState == MKSmartSwichOffline) {
            [self.view showCentralToast:@"Device offline,please check."];
            return;
        }
        [self updateFirmware];
        return;
    }
    if (indexPath.row == 3) {
        //开关上电默认状态
        if (self.deviceModel.device_mode == MKDevice_plug && self.deviceModel.plugState == MKSmartPlugOffline) {
            [self.view showCentralToast:@"Device offline,please check."];
            return;
        }
        if (self.deviceModel.device_mode == MKDevice_swich && self.deviceModel.swichState == MKSmartSwichOffline) {
            [self.view showCentralToast:@"Device offline,please check."];
            return;
        }
        [self readModifyPowerOnStatus];
        return;
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.dataList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    MKDeviceInfoCell *cell = [MKDeviceInfoCell initCellWithTableView:tableView];
    cell.dataModel = self.dataList[indexPath.row];
    return cell;
}

#pragma mark - event method
- (void)removeButtonPressed{
    [MKDeviceInfoAdopter deleteDeviceWithModel:self.deviceModel target:self reset:NO];
}

- (void)resetButtonPressed{
    [MKDeviceInfoAdopter deleteDeviceWithModel:self.deviceModel target:self reset:YES];
}

- (void)readFirmwareInfo{
    [[MKHudManager share] showHUDWithTitle:@"Loading..." inView:self.view isPenetration:NO];
    WS(weakSelf);
    [MKMQTTServerInterface readDeviceFirmwareInformationWithTopic:[self.deviceModel currentSubscribedTopic] mqttID:self.deviceModel.mqttID sucBlock:^{
        [[MKHudManager share] hide];
        MKDeviceInformationController *vc = [[MKDeviceInformationController alloc] init];
        MKDeviceModel *model = [[MKDeviceModel alloc] init];
        [model updatePropertyWithModel:weakSelf.deviceModel];
        vc.deviceModel = model;
        [weakSelf.navigationController pushViewController:vc animated:YES];
    } failedBlock:^(NSError *error) {
        [[MKHudManager share] hide];
        [weakSelf.view showCentralToast:error.userInfo[@"errorInfo"]];
    }];
}

- (void)readModifyPowerOnStatus {
    [[MKHudManager share] showHUDWithTitle:@"Reading..." inView:self.view isPenetration:NO];
    [MKMQTTServerInterface readDevicePowerOnStatusWithTopic:[self.deviceModel currentSubscribedTopic] mqttID:self.deviceModel.mqttID sucBlock:^{
        MKModifyPowerOnStatusController *vc = [[MKModifyPowerOnStatusController alloc] init];
        vc.deviceModel = self.deviceModel;
        [self.navigationController pushViewController:vc animated:YES];
    } failedBlock:^(NSError *error) {
        [[MKHudManager share] hide];
        [self.view showCentralToast:error.userInfo[@"errorInfo"]];
    }];
}

#pragma mark - 数据库操作
- (void)getDeviceLocalName{
    [[MKHudManager share] showHUDWithTitle:@"Reading..." inView:self.view isPenetration:NO];
    WS(weakSelf);
    [MKDeviceDataBaseManager selectLocalNameWithMacAddress:self.deviceModel.device_id sucBlock:^(NSString *localName) {
        [[MKHudManager share] hide];
        weakSelf.deviceModel.local_name = localName;
        [weakSelf loadDatas];
    } failedBlock:^(NSError *error) {
        [[MKHudManager share] hide];
        [weakSelf loadDatas];
    }];
}

- (void)updateDeviceLocalName:(NSString *)localName{
    [[MKHudManager share] showHUDWithTitle:@"Setting" inView:self.view isPenetration:NO];
    MKDeviceModel *model = [[MKDeviceModel alloc] init];
    [model updatePropertyWithModel:self.deviceModel];
    if (self.deviceModel.device_mode == MKDevice_swich) {
        model.swich_way_nameDic = self.deviceModel.swich_way_nameDic;
    }
    model.local_name = localName;
    WS(weakSelf);
    [MKDeviceDataBaseManager updateDevice:model sucBlock:^{
        [[MKHudManager share] hide];
        [weakSelf modifyNameSuccess:localName];
    } failedBlock:^(NSError *error) {
        [[MKHudManager share] hide];
        [weakSelf.view showCentralToast:error.userInfo[@"errorInfo"]];
    }];
}

#pragma mark - interface
- (void)updateFirmware{
    MKUpdateFirmwareController *vc = [[MKUpdateFirmwareController alloc] init];
    vc.deviceModel = self.deviceModel;
    [self.navigationController pushViewController:vc animated:YES];
}

- (BOOL)canClickEnable{
    if (self.deviceModel.device_mode == MKDevice_plug && self.deviceModel.plugState == MKSmartPlugOffline) {
        [self.view showCentralToast:@"Device offline,please check."];
        return NO;
    }
    if (self.deviceModel.device_mode == MKDevice_swich && self.deviceModel.swichState == MKSmartSwichOffline) {
        [self.view showCentralToast:@"Device offline,please check."];
        return NO;
    }
    if ([MKMQTTServerManager sharedInstance].managerState != MKMQTTSessionManagerStateConnected) {
        [self.view showCentralToast:@"Network error,please check."];
        return NO;
    }
    return YES;
}

#pragma mark - ui
- (void)loadSubViews{
    self.titleLabel.text = @"More";
    self.titleLabel.textColor = COLOR_WHITE_MACROS;
    self.custom_naviBarColor = UIColorFromRGB(0x0188cc);
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
        make.top.mas_equalTo(defaultTopInset);
        make.bottom.mas_equalTo(-VirtualHomeHeight);
    }];
}

- (void)modifyNameSuccess:(NSString *)localName{
    self.deviceModel.local_name = localName;
    MKDeviceInfoModel *nameModel = self.dataList[0];
    nameModel.rightMsg = localName;
    [UIView performWithoutAnimation:^{
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]]
                              withRowAnimation:UITableViewRowAnimationNone];
    }];
    [[NSNotificationCenter defaultCenter] postNotificationName:MKNeedReadDataFromLocalNotification object:nil];
}

- (void)loadDatas{
    MKDeviceInfoModel *nameModel = [[MKDeviceInfoModel alloc] init];
    nameModel.leftMsg = @"Modify device name";
    nameModel.rightMsg = self.deviceModel.local_name;
    [self.dataList addObject:nameModel];
    
    MKDeviceInfoModel *infoModel = [[MKDeviceInfoModel alloc] init];
    infoModel.leftMsg = @"Device information";
    [self.dataList addObject:infoModel];
    
    MKDeviceInfoModel *firmwareModel = [[MKDeviceInfoModel alloc] init];
    firmwareModel.leftMsg = @"Check firmware update";
    [self.dataList addObject:firmwareModel];
    
    MKDeviceInfoModel *powerStatusModel = [[MKDeviceInfoModel alloc] init];
    powerStatusModel.leftMsg = @"Modify power on status";
    [self.dataList addObject:powerStatusModel];
    
    MKDeviceInfoModel *aboutModel = [[MKDeviceInfoModel alloc] init];
    aboutModel.leftMsg = @"About";
    [self.dataList addObject:aboutModel];
    
    [self.tableView reloadData];
}

#pragma mark - setter & getter
- (MKBaseTableView *)tableView{
    if (!_tableView) {
        _tableView = [[MKBaseTableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = UIColorFromRGB(0xf2f2f2);
        
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableFooterView = [self footView];
    }
    return _tableView;
}

- (UIView *)footView{
    UIView *footView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight - 3 * 44.f - 64.f)];
    footView.backgroundColor = UIColorFromRGB(0xf2f2f2);
    
    UIButton *removeButton = [MKCommonlyUIHelper commonBottomButtonWithTitle:@"Remove Device" target:self action:@selector(removeButtonPressed)];
    UIButton *resetButton = [MKCommonlyUIHelper commonBottomButtonWithTitle:@"Reset" target:self action:@selector(resetButtonPressed)];
    [footView addSubview:removeButton];
    [footView addSubview:resetButton];
    [removeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(55.f);
        make.right.mas_equalTo(-55.f);
        make.bottom.mas_equalTo(resetButton.mas_top).mas_offset(-20.f);
        make.height.mas_equalTo(45.f);
    }];
    [resetButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(55.f);
        make.right.mas_equalTo(-55.f);
        make.bottom.mas_equalTo(-100.f);
        make.height.mas_equalTo(45.f);
    }];
    
    return footView;
}

- (NSMutableArray *)dataList{
    if (!_dataList) {
        _dataList = [NSMutableArray array];
    }
    return _dataList;
}

@end