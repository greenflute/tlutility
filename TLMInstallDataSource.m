//
//  TLMInstallDataSource.m
//  TeX Live Utility
//
//  Created by Adam Maxwell on 09/10/09.
/*
 This software is Copyright (c) 2009-2016
 Adam Maxwell. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 - Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 - Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in
 the documentation and/or other materials provided with the
 distribution.
 
 - Neither the name of Adam Maxwell nor the names of any
 contributors may be used to endorse or promote products derived
 from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TLMInstallDataSource.h"
#import "TLMProfileNode.h"
#import "TLMLogServer.h"

@implementation TLMInstallDataSource

@synthesize statusWindow = _statusWindow;
@synthesize outlineView = _outlineView;
@synthesize _controller;
@synthesize needsUpdate = _needsUpdate;

- (id)init
{
    self = [super init];
    if (self) {
        _archivePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
        NSString *appname = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
        _archivePath = [_archivePath stringByAppendingPathComponent:appname];
        [[NSFileManager defaultManager] createDirectoryAtPath:_archivePath withIntermediateDirectories:YES attributes:nil error:NULL];
        _archivePath = [[_archivePath stringByAppendingPathComponent:@"default.tluprofile"] copyWithZone:[self zone]];
        _metadata = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc
{
    [_archivePath release];
    [_outlineView release];
    [_rootNode release];
    [_statusWindow release];
    [_checkboxCell release];
    [_metadata release];
    [super dealloc];
}

- (void)_loadRootNode
{
    if (_rootNode) return;
    
    NSDictionary *metadata = nil;
    TLMProfileNode *newRoot = [[TLMProfileNode newDefaultProfileWithMetadata:&metadata] autorelease];
    const NSUInteger defaultProfileYear = [[metadata objectForKey:@"texliveyear"] integerValue];
    
    NSDictionary *archivedRoot = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:_archivePath])
        archivedRoot = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
    
    if ([archivedRoot isKindOfClass:[NSDictionary class]]) {
        
        TLMProfileNode *oldRoot = [archivedRoot objectForKey:@"_rootNode"];
        NSDictionary *oldMetadata = [archivedRoot objectForKey:@"_metadata"];
        const NSUInteger oldYear = [[oldMetadata objectForKey:@"texliveyear"] integerValue];
        
        if (oldYear == defaultProfileYear) {
            _rootNode = [oldRoot retain];
            [_metadata setDictionary:oldMetadata];
            TLMLog(__func__, @"Using previous profile for TeX Live %lu from %@", (unsigned long)oldYear, _archivePath);
        }
        else {
            TLMLog(__func__, @"Profile detected from older version; using new defaults instead.");
        }

    }
    else if (archivedRoot) {
        TLMLog(__func__, @"Profile detected from unreleased version; using new defaults instead.");
    }

    if (nil == _rootNode) {
        _rootNode = [newRoot retain];
        [_metadata setDictionary:metadata];
    }
}

- (void)awakeFromNib
{
    [self _loadRootNode];
    _checkboxCell = [[NSButtonCell alloc] initTextCell:@""];
    [_checkboxCell setButtonType:NSSwitchButton];
    [_checkboxCell setControlSize:NSSmallControlSize];
    [_checkboxCell setTarget:self];
    [_checkboxCell setAction:@selector(changeBoolean:)];
    [_outlineView reloadData];
}

- (void)changeBoolean:(id)sender
{
    TLMProfileNode *node = nil;
    if ([_outlineView clickedRow] >= 0)
        node = [_outlineView itemAtRow:[_outlineView clickedRow]];

    BOOL currentValue = [[node value] boolValue];
    [node setValue:[NSNumber numberWithBool:(!currentValue)]];
    [_outlineView reloadItem:node];
}

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    SEL action = [anItem action];
    if (@selector(netInstall:) == action)
        return YES;
    return NO;
}

- (NSString *)currentProfile
{
    return [TLMProfileNode profileStringWithRoot:_rootNode];
}

- (IBAction)netInstall:(id)sender;
{
    [_controller netInstall];
}

#pragma mark NSOutlineView datasource

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)anIndex ofItem:(TLMProfileNode *)item;
{
    return nil == item ? [_rootNode childAtIndex:anIndex] : [item childAtIndex:anIndex];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(TLMProfileNode *)item;
{
    return [item type] & TLMProfileRoot && [item numberOfChildren];
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(TLMProfileNode *)item;
{
    return nil == item ? [_rootNode numberOfChildren] : [item numberOfChildren];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(TLMProfileNode *)item;
{
    id value = [item valueForKey:[tableColumn identifier]];
    if ([item type] & TLMProfileRoot) {
        value = [value uppercaseString];
    }
    return value;
}

- (void)outlineView:(TLMOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(TLMProfileNode *)item;
{
    NSFont *defaultFont = [outlineView defaultFont];
    
    if (([item type] & TLMProfileRoot) != 0) {
        [cell setFont:[NSFont boldSystemFontOfSize:[defaultFont pointSize]]];
    }
    else if (defaultFont) {
        [cell setFont:defaultFont];
    }
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(TLMProfileNode *)item
{
    if (nil == tableColumn) return nil;
    if ([[tableColumn identifier] isEqualToString:@"value"] && [[item value] isKindOfClass:[NSValue class]]) {
        return _checkboxCell;
    }
    else if (([item type] & TLMProfileRoot) == 0) {
        // copy so font attributes can be set up properly by outline view
        return [[[tableColumn dataCell] copy] autorelease];
    }
    return [tableColumn dataCell];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(TLMProfileNode *)item
{
    return [item type] & TLMProfileRoot;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;
{
    NSParameterAssert([[tableColumn identifier] isEqualToString:@"value"]);
    [item setValue:object];    
    NSDictionary *archiveRoot = [NSDictionary dictionaryWithObjectsAndKeys:_rootNode, @"_rootNode", _metadata, @"_metadata", nil];
    [NSKeyedArchiver archiveRootObject:archiveRoot toFile:_archivePath];
}

- (id)outlineView:(NSOutlineView *)outlineView itemForPersistentObject:(id)object;
{
    [self _loadRootNode];
    for (NSUInteger r = 0; r < [_rootNode numberOfChildren]; r++)
        if ([[[_rootNode childAtIndex:r] name] isEqualToString:object])
            return [_rootNode childAtIndex:r];
    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView persistentObjectForItem:(TLMProfileNode *)item;
{
    return [item name];
}

- (void)outlineView:(TLMOutlineView *)outlineView writeSelectedRowsToPasteboard:(NSPasteboard *)pboard;
{
    if ([outlineView numberOfRows] != [outlineView numberOfSelectedRows])
        return NSBeep();
    
    NSString *profileString = [TLMProfileNode profileStringWithRoot:_rootNode];
    [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pboard setString:profileString forType:NSStringPboardType];
}

@end
