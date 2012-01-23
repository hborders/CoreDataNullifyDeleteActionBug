//
//  Parent.h
//  CoreDataNullifyDeleteActionBug
//
//  Created by Heath Borders on 1/20/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Child;

@interface Parent : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSSet *childs;
@end

@interface Parent (CoreDataGeneratedAccessors)

- (void)addChildsObject:(Child *)value;
- (void)removeChildsObject:(Child *)value;
- (void)addChilds:(NSSet *)values;
- (void)removeChilds:(NSSet *)values;

@end
