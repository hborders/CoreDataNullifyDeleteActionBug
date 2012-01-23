//
//  HBAppDelegate.m
//  CoreDataNullifyDeleteActionBug
//
//  Created by Heath Borders on 1/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "HBAppDelegate.h"
#import <CoreData/CoreData.h>
#import "Parent.h"
#import "Child.h"

#define DEMONSTRATE_BUG 1

@interface HBAppDelegate()

@property (nonatomic, retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain) NSManagedObjectContext *mainManagedObjectContext;

- (void) runButtonTouchUpInside;
- (void) runTestOnBackgroundThread;
- (void) backgroundMergeWithNotification: (id) notification;
- (void) runAssertionOnMainThread;

@end

@implementation HBAppDelegate

@synthesize window = _window;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize mainManagedObjectContext = _mainManagedObjectContext;

#pragma mark - init/dealloc

- (void)dealloc {
    self.window = nil;
    self.persistentStoreCoordinator = nil;
    self.mainManagedObjectContext = nil;
    
    [super dealloc];
}

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    UIButton *runButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [runButton addTarget:self
                  action:@selector(runButtonTouchUpInside)
        forControlEvents:UIControlEventTouchUpInside];
    runButton.frame = self.window.bounds;
    [runButton setTitle:@"Run" 
               forState:UIControlStateNormal];
    [self.window addSubview:runButton];
    
    NSManagedObjectModel *managedObjectModel;
#if DEMONSTRATE_BUG
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Nullify Delete Rule" 
                                         withExtension:@"mom"
                                          subdirectory:@"Model.momd"];
    managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:url] autorelease];
#else
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"No Action Delete Rule" 
                                         withExtension:@"mom"
                                          subdirectory:@"Model.momd"];
    managedObjectModel = [[[NSManagedObjectModel alloc] initWithContentsOfURL:url] autorelease];
#endif
    
    self.persistentStoreCoordinator = [[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel] autorelease];
    NSError *error = nil;
    NSURL *sqliteUrl = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/sqlite.sqlite"]];
    [[NSFileManager defaultManager] removeItemAtURL:sqliteUrl
                                              error:NULL];
    if (![self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                       configuration:nil
                                                                 URL:sqliteUrl 
                                                             options:nil
                                                               error:&error]) {
        NSLog(@"Error when creating sqlite: %@", [error localizedDescription]);
    }
    
    self.mainManagedObjectContext = [[[NSManagedObjectContext alloc] init] autorelease];
    [self.mainManagedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    
    Parent *initialParent = [NSEntityDescription insertNewObjectForEntityForName:@"Parent"
                                                   inManagedObjectContext:self.mainManagedObjectContext];
    initialParent.name = @"parent1";
    Child *initialChild = [NSEntityDescription insertNewObjectForEntityForName:@"Child"
                                                 inManagedObjectContext:self.mainManagedObjectContext];
    initialChild.name = @"child1";
    [initialParent addChildsObject:initialChild];
    
    error = nil;
    if (![self.mainManagedObjectContext save:&error]) {
        NSLog(@"Error when creating initial managed objects: %@", [error localizedDescription]);
    }
    
    return YES;
}

#pragma mark - private API

- (void) runButtonTouchUpInside {
    [self performSelectorInBackground:@selector(runTestOnBackgroundThread) 
                           withObject:nil];
}

- (void) runTestOnBackgroundThread {
    NSManagedObjectContext *managedObjectContext = [[[NSManagedObjectContext alloc] init] autorelease];
    [managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    
    NSFetchRequest *parentsFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Parent"];
    NSArray *parents = [managedObjectContext executeFetchRequest:parentsFetchRequest
                                                           error:NULL];
    for (Parent *parent in parents) {
        [managedObjectContext deleteObject:parent];
    }
    
    NSFetchRequest *childsFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Child"];
    NSArray *childs = [managedObjectContext executeFetchRequest:childsFetchRequest
                                                          error:NULL];
    
    Parent *adoptiveParent = [NSEntityDescription insertNewObjectForEntityForName:@"Parent"
                                                           inManagedObjectContext:managedObjectContext];
    adoptiveParent.name = @"parent2";
    for (Child *child in childs) {
        [adoptiveParent addChildsObject:child];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(backgroundMergeWithNotification:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:managedObjectContext];
    
    NSError *error = nil;
    if (![managedObjectContext save:&error]) {
        NSLog(@"Error when saving during test: %@", [error localizedDescription]);
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:managedObjectContext];
    
    NSLog(@"adoptive parent: %@", adoptiveParent);
    NSLog(@"childs: %@", childs);
    
    [self performSelectorOnMainThread:@selector(runAssertionOnMainThread)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void) backgroundMergeWithNotification: (id) notification {
    [self.mainManagedObjectContext performSelectorOnMainThread:@selector(mergeChangesFromContextDidSaveNotification:) 
                                                    withObject:notification
                                                 waitUntilDone:YES];
}

- (void) runAssertionOnMainThread {    
    NSFetchRequest *parentsFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Parent"];
    NSArray *parents = [self.mainManagedObjectContext executeFetchRequest:parentsFetchRequest
                                                                    error:NULL];
    for (Parent *parent in parents) {
        NSLog(@"parent name: %@ children:", parent);
        for (Child *child in parent.childs) {
            NSLog(@"\t child: %@", child);
        }
        NSLog(@"End of children for parent: %@", parent);
    }
    
    NSFetchRequest *childsFetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Child"];
    NSArray *childs = [self.mainManagedObjectContext executeFetchRequest:childsFetchRequest
                                                                   error:NULL];
    for (Child *child in childs) {
        NSLog(@"child: %@, parent: %@", child, child.parent);
    }
    
    Child *child = [childs lastObject];
    if (child.parent) {
        NSLog(@"The parent is still set! There is no bug!");
    } else {
        NSLog(@"The parent is no longer set! Is this a bug?");
    }
}

@end
